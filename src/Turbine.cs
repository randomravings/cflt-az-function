using System.Net;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Attributes;
using Microsoft.Azure.WebJobs.Extensions.OpenApi.Core.Enums;
using Microsoft.Extensions.Logging;
using Microsoft.OpenApi.Models;
using Newtonsoft.Json;

namespace Confluent.Examples.TurbineRepair
{
    public class Turbine(
        ILogger<Turbine> logger
    )
    {
        const double revenuePerkW = 0.12;
        const double technicianCost = 250;
        const double turbineCost = 100;

        [Function("TurbineRepair")]
        [OpenApiOperation(operationId: nameof(Run))]
        [OpenApiSecurity(
            "function_key",
            SecuritySchemeType.ApiKey,
            Name = "x-functions-key",
            In = OpenApiSecurityLocationType.Header
        )]
        [OpenApiRequestBody(
            "application/json",
            typeof(RequestModel[]),
            Description = "JSON Array with a list of Kafka records."
        )]
        [OpenApiResponseWithBody(
            statusCode: HttpStatusCode.OK,
            contentType: "application/json",
            bodyType: typeof(ResponsePayload[]),
            Description = "JSON Array with responses mapped by index to request."
        )]
        public async Task<IActionResult> Run(
            [HttpTrigger(AuthorizationLevel.Function, "post")]
            HttpRequest req
        )
        {
            LogUrl(req, logger);
            string requestBody = await new StreamReader(req.Body).ReadToEndAsync();
            try
            {
                var items = JsonConvert.DeserializeObject<RequestModel[]>(requestBody);
                if(items == null)
                    return BadRequest(requestBody);

                var repairTurbine = Compute(items);
                return new OkObjectResult(repairTurbine);
            }
            catch
            {
                return BadRequest(requestBody);
            }
        }

        private static ObjectResult BadRequest(string? requestBody)
        {
            return new BadRequestObjectResult(
                $"Invalid JSON payload {requestBody}."
            );
        }

        private static void LogUrl(HttpRequest req, ILogger<Turbine> logger)
        {
            var httpContext = req.HttpContext;
            var requestFeature = httpContext.Features.GetRequiredFeature<IHttpRequestFeature>();
            logger.LogInformation($"Trigger Url: {requestFeature.RawTarget}");
        }

        private static ResponsePayload[] Compute(RequestModel[] items)
        {
            return items.Select(item =>
            {
                double revenueOpportunity = item.Value.Capacity * revenuePerkW * 24;
                double costToFix = item.Value.Hours * technicianCost + turbineCost;
                string repairTurbine;

                if (revenueOpportunity > costToFix)
                    repairTurbine = "Yes";
                else
                    repairTurbine = "No";

                return new ResponsePayload
                {
                    Message = repairTurbine,
                    RevenueOpportunityUsd = revenueOpportunity,
                    CostToFixUsd = costToFix
                };
            }).ToArray();
        }


        public class RequestPayload
        {
            public int Hours { get; set; }
            public int Capacity { get; set; }
        }

        public class RequestModel
        {
            public object? Key { get; set; }
            public RequestPayload Value { get; set; } = new();
            public string Topic { get; set; } = "";
            public int Partition { get; set; }
            public long Offset { get; set; }
            public long Timestamp { get; set; }
        }

        public class ResponsePayload
        {
            public string Message { get; set; } = "";
            public double RevenueOpportunityUsd { get; set; }
            public double CostToFixUsd { get; set; }
        }
    }
}