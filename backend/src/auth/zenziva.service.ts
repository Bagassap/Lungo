import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class ZenzivaService {
  private readonly logger = new Logger(ZenzivaService.name);

  private toZenzivaPhone(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    if (digits.startsWith('62')) return '0' + digits.slice(2);
    if (digits.startsWith('0'))  return digits;
    if (digits.startsWith('8'))  return '0' + digits;
    return '0' + digits;
  }

  async sendOtp(phone: string, otp: string): Promise<boolean> {
    const userkey = process.env.ZENZIVA_USERKEY!;
    const passkey = process.env.ZENZIVA_APIKEY!;
    const url     = process.env.ZENZIVA_URL!;

    if (!userkey || !passkey || !url) {
      this.logger.error('Zenziva credentials tidak lengkap di .env');
      return false;
    }

    const zenzivaPhone = this.toZenzivaPhone(phone);
    this.logger.log(`Kirim OTP ke nomor: ${zenzivaPhone} (input: ${phone})`);

    try {
      const response = await axios.post(
        url,
        { userkey, passkey, to: zenzivaPhone, brand: 'Lungo', otp },
        { timeout: 10_000 },
      );

      const status  = response.data?.status;
      const success = status === '1' || status === 1;

      if (success) {
        this.logger.log(`Zenziva OTP sent to ${zenzivaPhone} (messageId: ${response.data?.messageId})`);
      } else {
        this.logger.warn(
          `Zenziva rejected for ${zenzivaPhone}: status=${status} | ${JSON.stringify(response.data)}`,
        );
      }
      return success;
    } catch (error: any) {
      const httpStatus = error?.response?.status;
      const body       = JSON.stringify(error?.response?.data ?? {});
      this.logger.error(
        `Zenziva error for ${zenzivaPhone}: HTTP ${httpStatus} | ${error?.message} | ${body}`,
      );
      return false;
    }
  }
}
