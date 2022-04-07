import asyncio
from azure.eventhub.aio import EventHubConsumerClient
from azure.eventhub.extensions.checkpointstoreblobaio import BlobCheckpointStore
import logging

async def on_event(partition_context, event):
    # Print and log the event data.
    logger = logging.getLogger()
    logger.info("Received the event: \"{}\" from the partition with ID: \"{}\"".format(event.body_as_str(encoding='UTF-8'), partition_context.partition_id))
    print("Received the event: \"{}\" from the partition with ID: \"{}\"".format(event.body_as_str(encoding='UTF-8'), partition_context.partition_id))

    # Update the checkpoint so that the program doesn't read the events
    # that it has already read when you run it next time.
    await partition_context.update_checkpoint(event)

async def main():
    # Create and configure logger
    logging.basicConfig()
    logging.getLogger().setLevel(logging.INFO)

    # Create an Azure blob checkpoint store to store the checkpoints.
    checkpoint_store = BlobCheckpointStore.from_connection_string("DefaultEndpointsProtocol=https;AccountName=pins2918421255funcstg;AccountKey=kO0M8EnSFDyEwPzP9TDyO84FzofFe0wzrB51BlYz3Rb+EtFHc1BanmH2T6S6TWqVCRI3E7ZgphxW+AStxjeWFA==;EndpointSuffix=core.windows.net", "messages")

    # Create a consumer client for the event hub.
    client = EventHubConsumerClient.from_connection_string("Endpoint=sb://pins-2918421255-eventhub.servicebus.windows.net/;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=VKDlXz9V63TOM0EVaIAtuiuZaOrZB2KxyHyfROtbVUo=", consumer_group="$Default", eventhub_name="acceptancetesteventhub", checkpoint_store=checkpoint_store)
    async with client:
        # Call the receive method. Read from the beginning of the partition (starting_position: "-1")
        await client.receive(on_event=on_event,  starting_position="-1")

if __name__ == '__main__':
    loop = asyncio.get_event_loop()
    # Run the main method.
    loop.run_until_complete(main())