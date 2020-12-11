import json
import logging
import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def lambda_handler(event, context):
    # Jsonify into payload
    payload = json.loads(event["body"])

    # Send message
    sent_message = sns_client.publish(
        PhoneNumber=payload["phone_number"],
        Message=payload["message"],
        MessageAttributes={
            'AWS.SNS.SMS.SenderID': {
                'DataType': 'String',
                'StringValue': 'SENDERID'
            },
            'AWS.SNS.SMS.SMSType': {
                'DataType': 'String',
                'StringValue': 'Promotional'
            }
        }
    )

    # Method Response
    response = {
        "body": "200 SMS notification sent successfully to the driver.",
        "statusCode": "200"
    }

    logger.info(sent_message)
    return response
