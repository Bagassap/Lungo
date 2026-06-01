import { Injectable } from '@nestjs/common';
import { RedisService } from './redis.service';

@Injectable()
export class TrackingService {
  constructor(private readonly redisService: RedisService) {}

  async getNearbyDrivers(lat: number, lng: number, radiusKm: number) {

    let results = await this._searchInRadius(lat, lng, radiusKm);

    if (results.length === 0 && radiusKm <= 50) {
      results = await this._searchInRadius(lat, lng, 50);
    }

    return results.sort((a, b) => a.distanceKm - b.distanceKm).slice(0, 3);
  }

  async getDriverCount(lat: number, lng: number, radiusKm: number = 3): Promise<{ count: number }> {
    const results = await this._searchInRadius(lat, lng, radiusKm);
    return { count: results.length };
  }

  async getDriverLocation(driverId: string) {
    return this.redisService.getDriverLocation(driverId);
  }

  private async _searchInRadius(lat: number, lng: number, radiusKm: number) {
    const keys = await this.redisService.getAllDriverKeys();
    const results: {
      driverId: string;
      latitude: number;
      longitude: number;
      distanceKm: number;
      expandedSearch: boolean;
    }[] = [];

    for (const key of keys) {
      const driverId = key.replace('driver:location:', '');
      const location = await this.redisService.getDriverLocation(driverId);
      if (!location) continue;

      const distance = this.haversine(lat, lng, location.latitude, location.longitude);
      if (distance <= radiusKm) {
        results.push({
          driverId,
          latitude: location.latitude,
          longitude: location.longitude,
          distanceKm: Math.round(distance * 100) / 100,
          expandedSearch: radiusKm > 3,
        });
      }
    }

    return results;
  }

  haversine(lat1: number, lon1: number, lat2: number, lon2: number): number {
    const R = 6371;
    const dLat = ((lat2 - lat1) * Math.PI) / 180;
    const dLon = ((lon2 - lon1) * Math.PI) / 180;
    const a =
      Math.sin(dLat / 2) * Math.sin(dLat / 2) +
      Math.cos((lat1 * Math.PI) / 180) *
        Math.cos((lat2 * Math.PI) / 180) *
        Math.sin(dLon / 2) *
        Math.sin(dLon / 2);
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return R * c;
  }
}
