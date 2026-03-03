"""Prayer log Lambda functions for Moatheny app."""
import json
import os
from datetime import datetime
import boto3
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get('PRAYERS_TABLE', 'moatheny-prayers-prod'))


def get_user_id(event):
    """Extract user ID from Cognito authorizer."""
    try:
        return event['requestContext']['authorizer']['claims']['sub']
    except (KeyError, TypeError):
        return None


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


def get_prayers(event, context):
    """Get prayer logs for a user."""
    user_id = get_user_id(event)
    if not user_id:
        return response(401, {'error': 'Unauthorized'})
    
    try:
        query_params = event.get('queryStringParameters') or {}
        start_date = query_params.get('startDate')
        end_date = query_params.get('endDate')
        
        if start_date and end_date:
            result = table.query(
                KeyConditionExpression=Key('userId').eq(user_id) & Key('date').between(start_date, end_date)
            )
        else:
            result = table.query(
                KeyConditionExpression=Key('userId').eq(user_id),
                ScanIndexForward=False,
                Limit=30
            )
        
        prayers = result.get('Items', [])
        
        return response(200, {'prayers': prayers})
    except Exception as e:
        print(f"Error getting prayers: {e}")
        return response(500, {'error': 'Internal server error'})


def save_prayer(event, context):
    """Save a prayer log entry."""
    user_id = get_user_id(event)
    if not user_id:
        return response(401, {'error': 'Unauthorized'})
    
    try:
        body = json.loads(event.get('body', '{}'))
        
        date = body.get('date') or datetime.utcnow().strftime('%Y-%m-%d')
        
        item = {
            'userId': user_id,
            'date': date,
            'fajr': body.get('fajr', False),
            'dhuhr': body.get('dhuhr', False),
            'asr': body.get('asr', False),
            'maghrib': body.get('maghrib', False),
            'isha': body.get('isha', False),
            'notes': body.get('notes'),
            'updatedAt': datetime.utcnow().isoformat()
        }
        
        item = {k: v for k, v in item.items() if v is not None}
        
        table.put_item(Item=item)
        
        return response(200, {'message': 'Prayer log saved', 'prayer': item})
    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON'})
    except Exception as e:
        print(f"Error saving prayer: {e}")
        return response(500, {'error': 'Internal server error'})
