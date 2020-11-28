#!/usr/bin/env node
import 'source-map-support/register';
import * as cdk from '@aws-cdk/core';
import { ServerlessNotificationServiceStack } from '../lib/serverless-notification-service-stack';

const app = new cdk.App();
new ServerlessNotificationServiceStack(app, 'ServerlessNotificationServiceStack');
