import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TariffConfig } from './entities/tariff_config.entity';
import { TariffHistory } from './entities/tariff_history.entity';

export interface ArgoPayload {
  rideId: string;
  distanceKm: number;
  durationMinutes: number;
  fare: number;
}

interface ArgoSession {
  startTime: number;
  distanceKm: number;
  interval: ReturnType<typeof setInterval>;
  onUpdate: (payload: ArgoPayload) => void;
}

@Injectable()
export class TariffService implements OnModuleInit {
  private basePrice     = 14000;
  private pricePerKm    = 2100;
  private pricePerMin   = 500;

  private readonly sessions = new Map<string, ArgoSession>();

  constructor(
    @InjectRepository(TariffConfig)
    private readonly configRepo: Repository<TariffConfig>,
    @InjectRepository(TariffHistory)
    private readonly historyRepo: Repository<TariffHistory>,
  ) {}

  async onModuleInit() {
    let config = await this.configRepo.findOne({ where: { id: 1 } });
    if (!config) {
      config = this.configRepo.create({
        id: 1,
        basePrice: 14000,
        pricePerKm: 2100,
        pricePerMinute: 500,
        minimumFare: 14000,
      });
      await this.configRepo.save(config);
    }
    this._syncCache(config);
  }

  private _syncCache(config: TariffConfig) {
    this.basePrice  = Number(config.basePrice);
    this.pricePerKm = Number(config.pricePerKm);
    this.pricePerMin = Number(config.pricePerMinute);
  }

  async getTariffConfig(): Promise<TariffConfig> {
    const config = await this.configRepo.findOne({ where: { id: 1 } });
    return config!;
  }

  async getHistory(limit = 20): Promise<TariffHistory[]> {
    return this.historyRepo.find({
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }

  async persistUpdate(
    dto: { basePrice?: number; pricePerKm?: number; pricePerMinute?: number },
    adminId: string,
    adminName: string,
  ): Promise<{ config: TariffConfig; changes: string[] }> {
    const config = await this.configRepo.findOne({ where: { id: 1 } });
    if (!config) throw new Error('Tariff config tidak ditemukan di database');

    const changes: string[] = [];

    if (dto.basePrice !== undefined && dto.basePrice !== Number(config.basePrice)) {
      changes.push(
        `Base fare: Rp ${Number(config.basePrice).toLocaleString('id-ID')} → Rp ${dto.basePrice.toLocaleString('id-ID')}`,
      );
      config.basePrice    = dto.basePrice;
      config.minimumFare  = dto.basePrice;
    }
    if (dto.pricePerKm !== undefined && dto.pricePerKm !== Number(config.pricePerKm)) {
      changes.push(
        `Per km: Rp ${Number(config.pricePerKm).toLocaleString('id-ID')} → Rp ${dto.pricePerKm.toLocaleString('id-ID')}`,
      );
      config.pricePerKm = dto.pricePerKm;
    }
    if (dto.pricePerMinute !== undefined && dto.pricePerMinute !== Number(config.pricePerMinute)) {
      changes.push(
        `Per menit: Rp ${Number(config.pricePerMinute).toLocaleString('id-ID')} → Rp ${dto.pricePerMinute.toLocaleString('id-ID')}`,
      );
      config.pricePerMinute = dto.pricePerMinute;
    }

    if (changes.length > 0) {
      config.updatedBy = adminId;
      await this.configRepo.save(config);
      this._syncCache(config);

      await this.historyRepo.save(
        this.historyRepo.create({
          change: changes.join(' | '),
          adminId,
          adminName,
        }),
      );
    }

    return { config, changes };
  }

  getRealtimeFare(distanceKm: number, durationMinutes: number): number {
    return Math.round(Math.max(
      this.basePrice,
      distanceKm * this.pricePerKm + durationMinutes * this.pricePerMin,
    ));
  }

  calculate(distanceKm: number): number {
    return Math.round(Math.max(this.basePrice, distanceKm * this.pricePerKm));
  }

  getTariffInfo() {
    return {
      basePrice:      this.basePrice,
      pricePerKm:     this.pricePerKm,
      pricePerMinute: this.pricePerMin,
      minimumFare:    this.basePrice,
    };
  }

  startArgo(rideId: string, onUpdate: (payload: ArgoPayload) => void): void {
    if (this.sessions.has(rideId)) return;

    const session: ArgoSession = {
      startTime: Date.now(),
      distanceKm: 0,
      interval: null as any,
      onUpdate,
    };

    session.interval = setInterval(() => {
      const durationMinutes = (Date.now() - session.startTime) / 60_000;
      const fare = this.getRealtimeFare(session.distanceKm, durationMinutes);
      onUpdate({ rideId, distanceKm: session.distanceKm, durationMinutes, fare });
    }, 5_000);

    this.sessions.set(rideId, session);
  }

  updateArgoDistance(rideId: string, distanceKm: number): void {
    const s = this.sessions.get(rideId);
    if (s) s.distanceKm = distanceKm;
  }

  stopArgo(rideId: string): number {
    const s = this.sessions.get(rideId);
    if (!s) return this.basePrice;
    clearInterval(s.interval);
    this.sessions.delete(rideId);
    const durationMinutes = (Date.now() - s.startTime) / 60_000;
    return this.getRealtimeFare(s.distanceKm, durationMinutes);
  }
}
