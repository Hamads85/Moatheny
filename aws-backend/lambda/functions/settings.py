"""Settings Lambda functions for Moatheny app."""
import json
import os
import boto3
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get('SETTINGS_TABLE', 'moatheny-settings-prod'))


class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super().default(obj)


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
        'body': json.dumps(body, cls=DecimalEncoder, ensure_ascii=False)
    }


def get_settings(event, context):
    """Get user settings."""
    user_id = get_user_id(event)
    if not user_id:
        return response(401, {'error': 'Unauthorized'})
    
    try:
        result = table.get_item(Key={'userId': user_id})
        settings = result.get('Item', {})
        
        if not settings:
            settings = {
                'userId': user_id,
                'calculationMethod': 4,
                'notificationsEnabled': True,
                'language': 'ar',
                'theme': 'auto',
                'lastSyncedAt': None
            }
        
        return response(200, settings)
    except Exception as e:
        print(f"Error getting settings: {e}")
        return response(500, {'error': 'Internal server error'})


def save_settings(event, context):
    """Save user settings."""
    user_id = get_user_id(event)
    if not user_id:
        return response(401, {'error': 'Unauthorized'})
    
    try:
        body = json.loads(event.get('body', '{}'))
        
        item = {
            'userId': user_id,
            'calculationMethod': body.get('calculationMethod', 4),
            'notificationsEnabled': body.get('notificationsEnabled', True),
            'language': body.get('language', 'ar'),
            'theme': body.get('theme', 'auto'),
            'latitude': Decimal(str(body.get('latitude', 0))) if body.get('latitude') else None,
            'longitude': Decimal(str(body.get('longitude', 0))) if body.get('longitude') else None,
            'cityName': body.get('cityName'),
            'lastSyncedAt': body.get('lastSyncedAt')
        }
        
        item = {k: v for k, v in item.items() if v is not None}
        
        table.put_item(Item=item)
        
        return response(200, {'message': 'Settings saved successfully', 'settings': item})
    except json.JSONDecodeError:
        return response(400, {'error': 'Invalid JSON'})
    except Exception as e:
        print(f"Error saving settings: {e}")
        return response(500, {'error': 'Internal server error'})
