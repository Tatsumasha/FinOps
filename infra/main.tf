provider "google" {
  project = var.project
  region  = var.region
}


resource "google_billing_budget" "budget_example" {
  billing_account = "016024-142CBD-3C523A"

  display_name = "FinOps Budget"

  amount {
    specified_amount {
      currency_code = "EUR"
      units         = 100 
    }
  }
  budget_filter {
    projects = ["projects/${var.project}"]
  }

  threshold_rules {
    threshold_percent = 0.5  # Notificar al 50% del presupuesto
  }

  threshold_rules {
    threshold_percent = 0.9  # Notificar al 90% del presupuesto
  }

  threshold_rules {
    threshold_percent = 1.0  # Notificar al 100% del presupuesto
  }
}
resource "google_pubsub_topic" "topic" {
  name = "finops-topic"
}


resource "google_monitoring_notification_channel" "pubsub_notification_channel" {
  project      = var.project
  display_name = "FinOps Notification Channel PubSub"
  type         = "pubsub"
  labels = {
    topic = google_pubsub_topic.topic.id
  }
}


resource "google_storage_bucket" "bucket" {
  name     = "finops-cfcode-bucket"
  location = "EU"
  force_destroy = true
}

resource "google_storage_bucket_object" "daily_report_code" {
  name   = "daily_report_code.zip"
  bucket = google_storage_bucket.bucket.name
  source = "./daily_report_code.zip"
}

resource "google_storage_bucket_object" "write_bq_code" {
  name   = "write_bq_code.zip"
  bucket = google_storage_bucket.bucket.name
  source = "./write_bq_code.zip"
}

resource "google_bigquery_dataset" "bq_dataset" {
  dataset_id                  = "FinOps"
  friendly_name               = "FinOps"
  description                 = "Dataset to hold the FinOps project tables"
}

resource "google_bigquery_table" "bq_table" {
  dataset_id          = google_bigquery_dataset.bq_dataset.dataset_id
  table_id            = "daily_alerts"
  deletion_protection = false

  schema = <<EOF
[
      {
        "name": "condition_name",
        "type": "STRING",
        "mode": "NULLABLE"
      },
      {
        "name": "observed_value",
        "type": "STRING",
        "mode": "NULLABLE"
      },
      {
        "name": "resource_name",
        "type": "STRING",
        "mode": "NULLABLE"
      },
      {
        "name": "resource_type_display_name",
        "type": "STRING",
        "mode": "NULLABLE"
      },
      {
        "name": "scoping_project_id",
        "type": "STRING",
        "mode": "NULLABLE"
      },
      {
        "name": "severity",
        "type": "STRING",
        "mode": "NULLABLE"
      },
      {
        "name": "started_at",
        "type": "TIMESTAMP",
        "mode": "NULLABLE"
      },
      {
        "name": "state",
        "type": "STRING",
        "mode": "NULLABLE"
      },
      {
        "name": "summary",
        "type": "STRING",
        "mode": "NULLABLE"
      },
      {
        "name": "threshold_value",
        "type": "STRING",
        "mode": "NULLABLE"
      },
      {
        "name": "url",
        "type": "STRING",
        "mode": "NULLABLE"
      }
]
EOF
}



resource "google_cloudfunctions_function" "function_daily_report_code" {
  name                  = "FinOpsDailyReport"
  description           = "Cloud funtion to send alert report to mail"
  runtime               = "python39"
  entry_point           = "daily_report"
  region                = "europe-west2"
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.daily_report_code.name
  trigger_http          = true
  available_memory_mb = 256

}

resource "google_cloudfunctions_function" "function_write_bq_code" {
  name                  = "WriteBQ"
  description           = "Cloud funtion to write alerts into big query"
  runtime               = "python39"
  entry_point           = "finops"
  region                = "europe-west2"
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.write_bq_code.name
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = google_pubsub_topic.topic.id
  }

  available_memory_mb = 256

}

resource "google_cloud_scheduler_job" "http_job" {
  name        = "finops-daily-report-trigger"
  description = "Job de Cloud Scheduler que hace una llamada HTTP al endpoint de la cloud function daily_report"

  schedule = "0 7 * * *"
  time_zone = "Europe/London"

  region = "europe-west1"

  http_target {
    uri = google_cloudfunctions_function.function_daily_report_code.https_trigger_url
    
    http_method = "POST"

    headers = {
      "Content-Type" = "application/json"
    }
  }

  retry_config {
    retry_count = 3
    min_backoff_duration = "5s"
    max_backoff_duration = "10s"
  }
}


resource "google_monitoring_alert_policy" "alert_policy" {
  project      = var.project
  display_name = "CPU Utilization < 50%"
  documentation {
    content = "The $${metric.display_name} of the $${resource.type} $${resource.label.instance_id} in $${resource.project} has exceeded 50% for over 1 minute."
  }
  combiner = "OR"
  conditions {
    display_name = "Condition 1"
    condition_threshold {
      comparison      = "COMPARISON_LT"
      duration        = "60s"
      filter          = "resource.type = \"gce_instance\" AND metric.type = \"compute.googleapis.com/instance/cpu/utilization\""
      threshold_value = "0.5"
      trigger {
        count = "1"
      }
    }
  }

  alert_strategy {
    notification_channel_strategy {
      renotify_interval = "1800s"
      notification_channel_names = [google_monitoring_notification_channel.pubsub_notification_channel.name]
    }
  }

  notification_channels = [google_monitoring_notification_channel.pubsub_notification_channel.name]

  user_labels = {
    severity = "warning"
  }
}



resource "google_monitoring_alert_policy" "bigquery_alert" {
  project      = var.project
  display_name = "BigQuery Usage Alert"
  combiner     = "OR"

  conditions {
    display_name = "BigQuery Storage Usage"
    condition_threshold {
      filter          = "resource.type = \"bigquery_dataset\" AND metric.type = \"bigquery.googleapis.com/storage/stored_bytes\""
      comparison      = "COMPARISON_GT"
      duration        = "60s"
      threshold_value = 1000000000
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_MEAN"
      }
    }
  }

  alert_strategy {
    notification_channel_strategy {
      renotify_interval = "1800s"
      notification_channel_names = [google_monitoring_notification_channel.pubsub_notification_channel.name]
    }
  }

  notification_channels = [google_monitoring_notification_channel.pubsub_notification_channel.name]
  enabled = true

  user_labels = {
    environment = "production"
  }
}

resource "google_monitoring_alert_policy" "bigquery_upload_alert" {
  project      = var.project
  display_name = "BigQuery Upload Alert"
  combiner     = "OR"

  conditions {
    display_name = "BigQuery Upload Usage"
    condition_threshold {
      filter          = "resource.type = \"bigquery_dataset\" AND metric.type = \"bigquery.googleapis.com/storage/uploaded_bytes\""
      comparison      = "COMPARISON_GT"
      duration        = "60s"
      threshold_value = 10000000
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_SUM"
        cross_series_reducer = "REDUCE_MEAN"
      }
    }
  }

  alert_strategy {
    notification_channel_strategy {
      renotify_interval = "1800s"
      notification_channel_names = [google_monitoring_notification_channel.pubsub_notification_channel.name]
    }
  }

  notification_channels = [google_monitoring_notification_channel.pubsub_notification_channel.name]
  enabled = true

  user_labels = {
    environment = "production"
  }
}

resource "google_monitoring_alert_policy" "cloud_functions_instance_alert" {
  display_name = "Cloud Functions Instance Alert"

  combiner = "OR"
  conditions {
    display_name = "Cloud Functions Instance Condition"

    condition_threshold {
      filter = "resource.type=\"cloud_function\" AND metric.type=\"cloudfunctions.googleapis.com/function/execution_count\""

      comparison   = "COMPARISON_GT"
      threshold_value = 100  
      duration     = "60s"
      
      aggregations {
        alignment_period     = "60s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.pubsub_notification_channel.name]

  user_labels = {
    environment = "production"
  }
}

# resource "google_monitoring_alert_policy" "job_active_worker_instances_alert" {
#   display_name = "Job Active Worker Instances Alert"

#   combiner = "OR"
#   conditions {
#     display_name = "Active Worker Instances Condition"

#     condition_threshold {
#       filter = "resource.type=\"dataflow_job\" AND metric.type=\"job/current_num_vcpus\""
#       comparison = "COMPARISON_GT"
#       threshold_value = 100
#       duration = "60s"
      
#       aggregations {
#         alignment_period = "60s"
#         per_series_aligner = "ALIGN_MAX"
#       }
#     }
#   }

#   notification_channels = [google_monitoring_notification_channel.pubsub_notification_channel.name]

#   documentation {
#     content  = "Alerta cuando el número de instancias activas de trabajadores supera el límite establecido."
#     mime_type = "text/markdown"
#   }

#   user_labels = {
#     environment = "production"
#   }
# }

resource "google_monitoring_alert_policy" "snapshot_backlog_bytes_alert" {
  display_name = "Snapshot Backlog Bytes Alert"

  combiner = "OR"
  conditions {
    display_name = "Snapshot Backlog Bytes Condition"

    condition_threshold {
      filter = "resource.type=\"pubsub_snapshot\" AND metric.type=\"snapshot/backlog_bytes\""
      comparison = "COMPARISON_GT"
      threshold_value = 500000000
      duration = "60s"

      aggregations {
        alignment_period = "60s"
        per_series_aligner = "ALIGN_MAX"
      }
    }
  }

  notification_channels = [google_monitoring_notification_channel.pubsub_notification_channel.name]

  documentation {
    content  = "Alerta cuando los bytes en cola del snapshot superan el límite establecido."
    mime_type = "text/markdown"
  }

  user_labels = {
    environment = "production"
  }
}