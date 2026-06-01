import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import { readFileSync } from 'fs';
import { join } from 'path';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    if (admin.apps.length) return;

    try {
      const saPath = join(process.cwd(), 'firebase-service-account.json');
      const serviceAccount = JSON.parse(readFileSync(saPath, 'utf-8'));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
      });
      this.logger.log(
        `Firebase Admin initialized (project: ${this.config.get('FIREBASE_PROJECT_ID')})`,
      );
    } catch (err: unknown) {
      this.logger.error(
        `Firebase Admin gagal inisialisasi: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }

  async sendNotification(
    fcmToken: string,
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    if (!admin.apps.length) return;
    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: { title, body },
        data,
        android: {
          priority: 'high',
          notification: { sound: 'default' },
        },
      });
    } catch (err: unknown) {
      this.logger.error(
        `FCM sendNotification gagal: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }

  async sendMulticast(
    fcmTokens: string[],
    title: string,
    body: string,
    data: Record<string, string> = {},
  ): Promise<void> {
    if (!admin.apps.length || !fcmTokens.length) return;
    try {
      const result = await admin.messaging().sendEachForMulticast({
        tokens: fcmTokens,
        notification: { title, body },
        data,
        android: {
          priority: 'high',
          notification: { sound: 'default' },
        },
      });
      this.logger.log(
        `FCM multicast: ${result.successCount} berhasil, ${result.failureCount} gagal`,
      );
    } catch (err: unknown) {
      this.logger.error(
        `FCM sendMulticast gagal: ${err instanceof Error ? err.message : String(err)}`,
      );
    }
  }
}
