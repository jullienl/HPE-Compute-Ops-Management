# Influxdb/Telegraf/Grafana for Compute Ops Management Carbon footprint report

To overcome the limitations of the Grafana Infinity plugin, this project uses Telegraf, InfluxData's data collection agent to collect and store the Compute Ops Management carbon footprint report data in an Influxdb database. As a result, the carbon footprint report data vizualisation can go beyond the current 7-day limit of Compute Ops Management. 

The Telegraf exec input plugin is used to run a Python script on a daily basis to generate a carbon footprint report and collect carbon emissions data for all servers (in kgCO2e) managed by Compute Ops Management.

The carbon emissions data can then be displayed in a time series Grafana graphical panel via an InfluxDB data source. 

![image](https://user-images.githubusercontent.com/13134334/204873169-6ca5393a-d98a-4d67-81b4-e439b4a3a507.png)

More information about the Exec input plugin can be found at https://github.com/influxdata/telegraf/tree/master/plugins/inputs/exec 

## Telegraf configuration 

File: `/etc/telegraf/telegraf.conf`

```
[[outputs.influxdb]]
  ## HTTP Basic Auth
   username = "telegraf"
   password = "xxxxxxxxxxxxxxx"

[[inputs.exec]]
  commands = ["/bin/python3 /tmp/COM-telegraf-Carbon-Footprint-collector.py"]
  interval = "24h" 
  timeout = "500s"
  data_format = "influx"
```

## Grafana panel

Data source: `Influxdb`

FROM: `carbon_Report`

SELECT: `field(emissions)`

ALIAS: `Carbon Emissions (kgCO2e)`

Example of a Grafana panel with a Telegraf agent interval = 10m

![image](https://user-images.githubusercontent.com/13134334/203847292-2ae20cbb-a4fb-486f-ab6a-31abd72d7925.png)


## Requirements
- Compute Ops Management API Client Credentials with appropriate roles, this includes:
   - A Client ID
   - A Client Secret
   - A Connectivity Endpoint
- Influxdb (with an admin account for telegraf)
- Telegraf
- Python3 (with requests and requests_oauthlib installed)

To learn more about how to set up the API client credentials, see https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us 


