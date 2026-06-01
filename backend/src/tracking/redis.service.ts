import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private client: Redis;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    this.client = new Redis({
      host: this.config.get<string>('REDIS_HOST', 'localhost'),
      port: this.config.get<number>('REDIS_PORT', 6379),
      maxRetriesPerRequest: 3,
      retryStrategy: (times) => Math.min(times * 200, 5000),
      reconnectOnError: (err) => err.message.includes('READONLY'),
      enableOfflineQueue: true,
      lazyConnect: false,
    });
    this.client.on('error', (err) => {
      console.error('[Redis] connection error:', err.message);
    });
  }

  async onModuleDestroy() {
    await this.client.quit();
  }

  async setDriverLocation(driverId: string, lat: number, lng: number): Promise<void> {
    const key = `driver:location:${driverId}`;
    await this.client.set(key, JSON.stringify({ latitude: lat, longitude: lng }), 'EX', 30);
  }

  async getDriverLocation(driverId: string): Promise<{ latitude: number; longitude: number } | null> {
    const value = await this.client.get(`driver:location:${driverId}`);
    if (!value) return null;
    return JSON.parse(value);
  }

  async deleteDriverLocation(driverId: string): Promise<void> {
    await this.client.del(`driver:location:${driverId}`);
  }

  async getAllDriverKeys(): Promise<string[]> {
    return this.client.keys('driver:location:*');
  }

  async setPassengerLocation(rideId: string, lat: number, lng: number): Promise<void> {
    await this.client.set(`passenger:location:${rideId}`, JSON.stringify({ latitude: lat, longitude: lng }), 'EX', 60);
  }

  async getPassengerLocation(rideId: string): Promise<{ latitude: number; longitude: number } | null> {
    const value = await this.client.get(`passenger:location:${rideId}`);
    if (!value) return null;
    return JSON.parse(value);
  }

  async deletePassengerLocation(rideId: string): Promise<void> {
    await this.client.del(`passenger:location:${rideId}`);
  }
}
