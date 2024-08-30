gcloud functions deploy dailyReport \
  --runtime python39 \
  --region europe-west2 \
  --trigger-http \
  --entry-point daily_report \
  --service-account=pablo-magan@practica-cloud-286009.iam.gserviceaccount.com \
  --project practica-cloud-286009
