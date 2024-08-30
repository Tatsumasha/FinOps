import json
import base64
from constants import recommender_ids
from google.cloud import bigquery
from sendgrid import SendGridAPIClient
from sendgrid.helpers.mail import Mail
from googleapiclient.discovery import build

billing_client = build('cloudbilling', 'v1')
recommender_client = build('recommender', 'v1')

PROJECT_ID = 'practica-cloud-286009'

def dicts_to_html_table(dict_list):
    if not dict_list:
        return "<table></table>"

    headers = ['description', 'priority','recommenderSubtype', 'lastRefreshTime',
               'primaryImpact', 'stateInfo', 'targetResources']

    # Comenzar la tabla HTML
    # html = '<table border="1" cellpadding="3" cellspacing="0" style="width: 200%; max-width: 600px;">\n'
    html = '<table border="1" cellpadding="3" cellspacing="0" style="width: 200;">\n'
    

    # Crear la fila de encabezados
    html += "  <tr>\n"
    for header in headers:
        if header == "description":
            html += f"    <th style='width: 200px;'>{header}</th>\n"
        else:
            html += f"    <th>{header}</th>\n"



    # Crear las filas de la tabla
    for dictionary in dict_list:
        html += "  <tr>\n"
        for header in headers:
            if header == "primaryImpact":
                category = dictionary[header]["category"]
                html += f"    <td>{category}</td>\n"
            elif header == "stateInfo":
                state = dictionary[header]["state"]
                html += f"    <td>{state}</td>\n"
            elif header =="lastRefreshTime":
                date_formated = dictionary.get(header,'').split('T')[0]
                html += f"    <td>{date_formated}</td>\n"
            else:
                html += f"    <td>{dictionary.get(header,'')}</td>\n"
        html += "  </tr>\n"

    # Cerrar la tabla
    html += "</table>"

    return html

def get_cost_saving_recommendations():
    recommendations = []
    for id in recommender_ids:
        recommender_name = f'projects/{PROJECT_ID}/locations/global/recommenders/{id}'
        request = recommender_client.projects().locations().recommenders().recommendations().list(parent=recommender_name)
        response = request.execute()
        for recommendation in response.get('recommendations', []):
            recommendations.append(recommendation)
    return recommendations



def daily_report(request):


    client = bigquery.Client()
    
    SENDGRID_API_KEY=''


    query_job = client.query("SELECT * FROM `practica-cloud-286009.FinOps.daily_alerts` LIMIT 10")
    results = query_job.result()
    df = results.to_dataframe()

    alerts_table = df.to_html(index=False, border=1, classes="table", justify="center", header=True)
    
    recommendations = get_cost_saving_recommendations()

    recommendations_table = dicts_to_html_table(recommendations)

    mail_body = f"""
        <!DOCTYPE html>
        <html lang="es">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Correo con Tablas</title>
        </head>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333333;">

            <p>Buenos dias,</p>

            <p>Este es el reporte diario de la aplicacion FinOps:</p>

            <p>Esta tabla muestra las alertas de gcp </p>

            {alerts_table}

            <p>Esta tabla muestra las acciones recomendadas de gcp:</p>

            {recommendations_table}


        </body>
        </html>
        """


    message = Mail(
        from_email='pablo.magan@bluetab.net',
        to_emails='pablo.magan@bluetab.net',
        subject='FinOps daily report',
        html_content=mail_body)
    try:
        sg = SendGridAPIClient(SENDGRID_API_KEY)
        response = sg.send(message)
        print(response.status_code)
        print(response.body)
        print(response.headers)
    except Exception as e:
        print(e)
        print(e.message)

    
    