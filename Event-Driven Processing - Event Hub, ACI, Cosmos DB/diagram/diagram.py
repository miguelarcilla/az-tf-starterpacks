from diagrams import Cluster, Diagram
from diagrams.azure.analytics import EventHubs
from diagrams.azure.compute import ContainerInstances
from diagrams.azure.compute import VM
from diagrams.azure.database import CosmosDb
from diagrams.azure.integration import ServiceBus
from diagrams.azure.storage import StorageAccounts


with Diagram("Event-Driven Processing", show=False):
    source = EventHubs("Event Hub")

    with Cluster("Event Processor"):
        with Cluster("ACI Listeners"):
            workers = [ContainerInstances("Worker 1"),
                       ContainerInstances("Worker 2"),
                       ContainerInstances("Worker X")]

        queue = ServiceBus("Queue")

        with Cluster("Processors"):
            handlers = [VM("Processor VM")]

    cosmosdb = CosmosDb("Cosmos DB (MongoDB)")
    storage = StorageAccounts("Blob Storage")

    source >> workers >> queue >> handlers
    handlers >> cosmosdb
    handlers >> storage