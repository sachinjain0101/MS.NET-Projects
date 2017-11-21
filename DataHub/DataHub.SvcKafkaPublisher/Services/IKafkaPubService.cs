using DataHub.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace DataHub.SvcKafkaPublisher.Services
{
    public interface IKafkaPubService
    {
        Boolean PublishData(List<TimeHistDetail> thds);
    }
}
