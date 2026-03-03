"""Analytics Lambda function for Moatheny app."""
import json
import os
import uuid
from datetime import datetime
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get('ANALYTICS_TABLE', 'moatheny-analytics-prod'))


def response(status_code, body):
    """Create API Gateway response."""
    return {
        'statusCode': status_code,
        'headers': {
            'Content-Type': 'application/json',
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        },
        'body': json.dumps(body, ensure_ascii=False)
    }


def log_event(event, context):
    """
    Log an analytics event.
    
    This endpoint is public (no auth required) for basic analytics.
    """
    try:
        body = json.loads(event.get('body', '{}'))
        
        user_id = body.get('userId') or body.get('deviceId') or 'anonymous'
        event_name = body.get('event')
        
        if not event_name:
            return response(400, {'error': 'event is required'})
        
        timestamp = datetime.utcnow().isoformat()
        
        ttl = int(datetime.utcnow().timestamp()) + (90 * 24 * 60 * 60)
        
        item = {
            'userId': user_id,
            'timestamp': timestamp,
            'event': event_name,
            'properties': body.get('properties', {}),
            'appVersion': body.get('appVersion'),
            'platform': body.get('platform', 'ios'),
            'ttl': ttl
        }
        
        item = {k: v for k, v in item.items() if v is not None}
        
        table.put_item(Item=item)
        
        return response(200, {'message': 'Event logged'})
    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON'})
    except Exception as e:
        print(f"Error logging event: {e}")
        return response(500, {'error': 'Internal server error'})
