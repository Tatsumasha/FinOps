cd cloud_functions/daily_report
zip -r daily_report_code.zip .
mv daily_report_code.zip ../../
cd ../write_bq
zip -r write_bq_code.zip .
mv write_bq_code.zip ../../