import json
import base64
from google.cloud import bigquery
from googleapiclient.discovery import build

billing_client = build('cloudbilling', 'v1')
recommender_client = build('recommender', 'v1')

PROJECT_ID = 'practica-cloud-286009'


def finops(event, context):

    client = bigquery.Client()
    
    table_id = "practica-cloud-286009.FinOps.daily_alerts"
    table = client.get_table(table_id)
    schema = ["condition_name","resource_name","resource_type_display_name",
          "scoping_project_id","severity","started_at","state","summary",
          "threshold_value","observed_value","url"]
    
    pubsub_message = base64.b64decode(event['data']).decode('utf-8')
    data = json.loads(pubsub_message)

    new_df = {}
    for field in schema:
        new_df[field] = data["incident"][field]


    errors = client.insert_rows_json(table, [new_df])

    if errors:
        print(f"Error al insertar en BigQuery: {errors}")
    else:
        print("Inserción exitosa en BigQuery")
