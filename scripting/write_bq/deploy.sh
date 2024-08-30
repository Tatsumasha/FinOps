gcloud functions deploy getBudgetAlertsAndRecommendations \
  --runtime python39 \
  --region europe-west2 \
  --trigger-topic finops-topic \
  --entry-point finops \
  --service-account=pablo-magan@practica-cloud-286009.iam.gserviceaccount.com \
  --project practica-cloud-286009
