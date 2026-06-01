import Redis from 'ioredis';

const TTL_SECONDS      = 5 * 60;  // OTP valid 5 menit
const BLOCK_TTL        = 15 * 60; // Blokir 15 menit setelah 3x salah
const MAX_OTP_ATTEMPTS = 3;

const redis = new Redis({
  host: process.env.REDIS_HOST || 'localhost',
  port: parseInt(process.env.REDIS_PORT || '6379', 10),
  maxRetriesPerRequest: 3,
  retryStrategy: (times) => Math.min(times * 200, 3000),
  enableOfflineQueue: false,
  lazyConnect: false,
});

redis.on('error', (err) => {
  console.error('[OtpStore] Redis error:', err.message);
});

class OtpStore {
  // Normalisasi key agar 08x, 62x, +62x, 8x semua map ke key yang sama
  private normalize(phone: string): string {
    const digits = phone.replace(/\D/g, '');
    return digits.startsWith('0')  ? '62' + digits.slice(1)
         : digits.startsWith('62') ? digits
         : digits.startsWith('8')  ? '62' + digits
         : digits;
  }

  private key(phone: string)     { return `otp:${this.normalize(phone)}`; }
  private blockKey(phone: string){ return `otp_block:${this.normalize(phone)}`; }
  private attemptKey(phone: string){ return `otp_attempt:${this.normalize(phone)}`; }

  async setOtp(phone: string, otp: string): Promise<void> {
    await redis.setex(this.key(phone), TTL_SECONDS, otp);
    // Reset attempt counter saat OTP baru dikirim
    await redis.del(this.attemptKey(phone));
  }

  async getOtp(phone: string): Promise<string | null> {
    return redis.get(this.key(phone));
  }

  async deleteOtp(phone: string): Promise<void> {
    await redis.del(this.key(phone));
  }

  // Brute force protection
  async isBlocked(phone: string): Promise<{ blocked: boolean; ttl: number }> {
    const ttl = await redis.ttl(this.blockKey(phone));
    return { blocked: ttl > 0, ttl };
  }

  async recordFailedAttempt(phone: string): Promise<number> {
    const key = this.attemptKey(phone);
    const attempts = await redis.incr(key);
    if (attempts === 1) await redis.expire(key, BLOCK_TTL);
    if (attempts >= MAX_OTP_ATTEMPTS) {
      await redis.setex(this.blockKey(phone), BLOCK_TTL, '1');
      await redis.del(key);
      await redis.del(this.key(phone));
    }
    return attempts;
  }

  async clearAttempts(phone: string): Promise<void> {
    await redis.del(this.attemptKey(phone));
    await redis.del(this.blockKey(phone));
  }
}

export const otpStore = new OtpStore();
