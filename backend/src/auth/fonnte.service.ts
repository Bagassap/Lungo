import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class FonnteService {
  private readonly logger = new Logger(FonnteService.name);

  async sendOtp(phone: string, otp: string): Promise<boolean> {
    const token = process.env.FONNTE_TOKEN;
    if (!token) {
      this.logger.warn('FONNTE_TOKEN tidak ada di .env — skip Fonnte');
      return false;
    }

    const normalized = phone.replace(/^\+/, '');

    try {
      const response = await axios.post(
        'https://api.fonnte.com/send',
        {
          target:      normalized,
          message:     `Kode OTP Lungo Anda: *${otp}*\nBerlaku 5 menit. Jangan bagikan ke siapapun.`,
          countryCode: '62',
        },
        {
          headers: {
            Authorization: token,
            'Content-Type': 'application/json',
          },
          timeout: 10_000,
        },
      );

      const ok = response.data?.status === true;
      if (ok) {
        this.logger.log(`Fonnte OTP sent to ${normalized}`);
      } else {
        this.logger.warn(`Fonnte rejected: ${JSON.stringify(response.data)}`);
      }
      return ok;
    } catch (error: any) {
      const body = JSON.stringify(error?.response?.data ?? {});
      this.logger.error(`Fonnte error for ${normalized}: ${error?.message} | ${body}`);
      return false;
    }
  }
}
