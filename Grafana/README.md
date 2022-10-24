# Grafana Dashboard for HPE GreenLake for Compute Ops Management

> For more information on how to monitor HPE GreenLake for Compute Ops Management infrastructure with Grafana Metrics Dashboards, see this [blog](https://developer.hpe.com/blog/how-to-monitor-hpe-compute-ops-management/) on the HPE Developer website. 

`Grafana Dashboard for HPE Compute Ops Management.json` contains everything you need (layout, variables, styles, data sources, queries, etc.) to import a predefined dashboard with different panels for HPE Compute Ops Management, including carbon emissions reports, server information and health, firmware bundles, groups information, etc.

![2022-10-21 11_14_38-HPE COM using Infinity (UQL + native API calls) - Grafana — Mozilla Firefox](https://user-images.githubusercontent.com/13134334/197200746-6e5c7b19-362f-4f65-a844-115f97c922fb.png)


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


## Prerequisites

*  HPE Compute Ops Management API client credentials are required (this consists of a client ID and a client secret)
*  Infinity plugin is required

## Infinity plugin installation

From an SSH session on the Grafana server, enter:
> grafana-cli plugins install yesoreyeram-infinity-datasource

Then restart the Grafana service:
> service grafana-server restart

For more details on how to install the Infinity plugin, you can check out the [Infinity GitHub repository](https://github.com/yesoreyeram/grafana-infinity-datasource).