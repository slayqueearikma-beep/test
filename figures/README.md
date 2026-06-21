# Screenshot filenames

Save the eight screenshots in this directory using these exact filenames so the LaTeX report can include them:

| Filename | Screenshot content |
| --- | --- |
| `azure_security_recommendations.png` | Microsoft Defender for Cloud security recommendations list |
| `log_analytics_table_counts.png` | Log Analytics query showing counts by table name |
| `log_analytics_azure_activity.png` | Log Analytics query showing AzureActivity count |
| `azure_advisor_overview.png` | Azure Advisor overview cards for cost, security, reliability, operational excellence, and performance |
| `azure_cost_accumulated_scope.png` | Azure Cost Management accumulated cost and forecast view with filters |
| `azure_cost_forecast_detail.png` | Azure Cost Management detailed accumulated/forecast cost chart |
| `azure_student_offer_details.png` | Azure for Students credit details |
| `terraform_init_success.png` | Terminal output showing successful `terraform init` |

The main report uses `\safeincludegraphics`, so missing images render as placeholders until the PNG files are added.
