# Grafana Dashboard for HPE Compute Ops Management

`Grafana Dashboard for HPE Compute Ops Management.json` contains everything you need (layout, variables, styles, data sources, queries, etc.) to import a predefined dashboard with different panels for HPE Compute Ops Management, including carbon emissions reports, server information and health, firmware bundles, groups information, etc.

Before importing the dashboard, be sure to change the clientID and clientSecret values with your HPE Compute Ops Management API client credentials generated from the HPE GreenLake Cloud Platform (GLCP).

```
  {
      "name": "VAR_CLIENTID",
      "type": "constant",
      "label": "clientID",
      "value": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
      "description": ""
    },
    {
      "name": "VAR_CLIENTSECRET",
      "type": "constant",
      "label": "clientSecret",
      "value": "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
      "description": ""
    }
```

To learn how to import a Grafana dashboard, please see [Export and Import](https://grafana.com/docs/grafana/v9.0/dashboards/export-import/) from the Grafana docs