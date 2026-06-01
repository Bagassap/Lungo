import {
  Injectable,
  UnauthorizedException,
  ConflictException,
  NotFoundException,
  InternalServerErrorException,
  ForbiddenException,
  Logger,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcryptjs';
import { User, UserRole } from '../users/entities/user.entity';
import { Driver } from '../drivers/entities/driver.entity';
import { RegisterDto } from './dto/register.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { LoginDto } from './dto/login.dto';
import { CompleteRegistrationDto } from './dto/complete-registration.dto';
import { otpStore } from './otp.store';
import { ZenzivaService } from './zenziva.service';
import { AdminNotification } from '../admin/entities/admin_notification.entity';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(User)
    private readonly usersRepo: Repository<User>,
    @InjectRepository(Driver)
    private readonly driverRepo: Repository<Driver>,
    @InjectRepository(AdminNotification)
    private readonly adminNotifRepo: Repository<AdminNotification>,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly zenzivaService: ZenzivaService,
  ) {}

  async sendOtp(phone: string) {
    const users = await this.usersRepo.find({ where: { phone } });
    let isNewUser = false;

    if (users.length === 0) {
      const user = this.usersRepo.create({
        phone,
        name: null as any,
        role: null as any,
        isVerified: false,
      });
      await this.usersRepo.save(user);
      isNewUser = true;
    } else if (users.length === 1) {
      const u = users[0];
      if (!u.isVerified || !u.name || !u.role) isNewUser = true;
    }

    const otp = this.generateOtp();
    await otpStore.setOtp(phone, otp);

    const showOtp = this.configService.get<string>('SHOW_OTP') === 'true';
    const isDev   = this.configService.get<string>('NODE_ENV') !== 'production';

    const sent = await this.zenzivaService.sendOtp(phone, otp);
    if (!sent) {
      this.logger.error(`OTP gagal dikirim ke ${phone}`);
      if (!isDev && !showOtp) {
        throw new InternalServerErrorException(
          'Gagal mengirim OTP via WhatsApp. Coba lagi dalam beberapa saat.',
        );
      }
      this.logger.warn(`[DEV] Zenziva gagal, OTP ${otp} disisipkan langsung di response`);
    } else {
      this.logger.log(`OTP berhasil dikirim ke ${phone} | kode: ${otp}`);
    }

    return {
      message: 'OTP telah dikirim',
      isNewUser,
      ...((isDev || showOtp) && { otp }),
    };
  }

  async completeRegistration(userId: string, dto: CompleteRegistrationDto) {
    const user = await this.usersRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User tidak ditemukan');

    const isNew = !user.name || !user.role;
    user.name = dto.name;
    user.role = dto.role;
    await this.usersRepo.save(user);

    if (dto.role === UserRole.DRIVER) {
      const existing = await this.driverRepo.findOne({ where: { userId } });
      if (!existing) {
        const driver = this.driverRepo.create({
          userId,
          vehicleType: 'MOTOR',
          vehiclePlate: '',
          registrationStatus: 'PENDING',
        });
        await this.driverRepo.save(driver);
      }
    }

    if (isNew) {
      const roleLabel = dto.role === UserRole.DRIVER ? 'Driver' : 'Penumpang';
      await this.adminNotifRepo.save(
        this.adminNotifRepo.create({
          type: 'NEW_USER',
          title: 'Pengguna Baru Mendaftar',
          body: `${dto.name} mendaftar sebagai ${roleLabel}`,
          targetId: userId,
        }),
      );
    }

    return {
      success: true,
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        role: user.role,
        isVerified: user.isVerified,
      },
    };
  }

  async register(dto: RegisterDto) {
    const existing = await this.usersRepo.findOne({ where: { phone: dto.phone } });
    if (existing) throw new ConflictException('Nomor HP sudah terdaftar');

    const user = this.usersRepo.create({
      phone: dto.phone,
      name: dto.name,
      role: dto.role,
    });
    await this.usersRepo.save(user);

    if (dto.role === 'DRIVER') {
      const driver = this.driverRepo.create({
        userId: user.id,
        vehicleType: dto.vehicleType ?? 'MOTOR',
        vehiclePlate: dto.vehiclePlate ?? '-',
        registrationStatus: 'PENDING',
      });
      await this.driverRepo.save(driver);
    }

    const otp = this.generateOtp();
    await otpStore.setOtp(dto.phone, otp);

    const showOtp2 = this.configService.get<string>('SHOW_OTP') === 'true';
    const isDev2   = this.configService.get<string>('NODE_ENV') !== 'production';

    const sent = await this.zenzivaService.sendOtp(dto.phone, otp);
    if (!sent) {
      this.logger.error(`OTP gagal dikirim ke ${dto.phone} (register)`);
      if (!isDev2 && !showOtp2) {
        throw new InternalServerErrorException(
          'Gagal mengirim OTP via WhatsApp. Coba lagi dalam beberapa saat.',
        );
      }
      this.logger.warn(`[DEV] Zenziva gagal, OTP ${otp} disisipkan langsung di response`);
    } else {
      this.logger.log(`OTP berhasil dikirim ke ${dto.phone} (register) | kode: ${otp}`);
    }

    return {
      message: 'OTP telah dikirim',
      ...((isDev2 || showOtp2) && { otp }),
    };
  }

  async verifyOtp(dto: VerifyOtpDto) {
    // Cek apakah nomor HP sedang diblokir karena salah OTP berkali-kali
    const { blocked, ttl } = await otpStore.isBlocked(dto.phone);
    if (blocked) {
      const menit = Math.ceil(ttl / 60);
      throw new ForbiddenException(
        `Nomor diblokir sementara karena terlalu banyak percobaan. Coba lagi dalam ${menit} menit.`,
      );
    }

    const storedOtp = await otpStore.getOtp(dto.phone);
    if (!storedOtp || storedOtp !== dto.otp) {
      const attempts = await otpStore.recordFailedAttempt(dto.phone);
      const remaining = 3 - attempts;
      const msg = remaining > 0
        ? `OTP tidak valid. ${remaining} percobaan tersisa.`
        : 'OTP tidak valid. Nomor diblokir 15 menit.';
      throw new UnauthorizedException(msg);
    }

    const users = await this.usersRepo.find({ where: { phone: dto.phone } });
    if (users.length === 0) throw new NotFoundException('User tidak ditemukan');

    await otpStore.clearAttempts(dto.phone);
    await otpStore.deleteOtp(dto.phone);

    // Verified users (fully registered) always see the role picker so they
    // can choose which role to enter — even if they currently have only one.
    const verifiedUsers = users.filter((u) => u.isVerified && u.name && u.role);
    if (verifiedUsers.length > 0) {
      const availableRoles = verifiedUsers.map((u) => u.role).filter(Boolean) as string[];
      const tempToken = this.jwtService.sign(
        { phone: dto.phone, purpose: 'role-select' },
        { expiresIn: '10m' },
      );
      return { multipleRoles: true, availableRoles, phone: dto.phone, tempToken };
    }

    // No verified user found — new registration flow
    const user = users[0];
    const isNewUser = !user.name || !user.role;

    user.isVerified = true;
    const tokens = await this.generateTokens(user);
    user.refreshToken = await bcrypt.hash(tokens.refreshToken, 10);
    await this.usersRepo.save(user);

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      isNewUser,
      user: {
        id: user.id,
        name: user.name ?? '',
        phone: user.phone,
        role: user.role ?? '',
        isVerified: true,
      },
    };
  }

  async selectRole(phone: string, role: string, tempToken?: string) {
    if (tempToken) {
      let payload: any;
      try {
        payload = this.jwtService.verify(tempToken);
      } catch {
        throw new UnauthorizedException('Token kadaluarsa, verifikasi OTP ulang');
      }
      if (payload.purpose !== 'role-select' || payload.phone !== phone) {
        throw new UnauthorizedException('Token tidak valid');
      }
    }

    let user = await this.usersRepo.findOne({ where: { phone, role: role as UserRole } });

    // Auto-create PASSENGER account if the user is switching from DRIVER and
    // no PASSENGER entity exists yet for this phone number.
    if (!user && role === UserRole.PASSENGER) {
      const source = await this.usersRepo.findOne({ where: { phone } });
      if (!source) throw new NotFoundException('Akun tidak ditemukan untuk nomor ini');
      user = this.usersRepo.create({
        phone,
        name: source.name,
        role: UserRole.PASSENGER,
        isVerified: true,
      });
      user = await this.usersRepo.save(user);
    }

    if (!user) throw new NotFoundException(`Akun ${role} tidak ditemukan untuk nomor ini`);

    user.isVerified = true;
    const tokens = await this.generateTokens(user);
    user.refreshToken = await bcrypt.hash(tokens.refreshToken, 10);
    await this.usersRepo.save(user);

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      user: {
        id: user.id,
        name: user.name ?? '',
        phone: user.phone,
        role: user.role ?? '',
        isVerified: true,
      },
    };
  }

  async login(dto: LoginDto) {
    const user = await this.usersRepo.findOne({ where: { phone: dto.phone } });
    if (!user) throw new NotFoundException('User tidak ditemukan');
    if (!user.isVerified) {
      throw new UnauthorizedException('Akun belum terverifikasi, silakan daftar terlebih dahulu');
    }

    const otp = this.generateOtp();
    await otpStore.setOtp(dto.phone, otp);

    const showOtp3 = this.configService.get<string>('SHOW_OTP') === 'true';
    const isDev3   = this.configService.get<string>('NODE_ENV') !== 'production';

    const sent = await this.zenzivaService.sendOtp(dto.phone, otp);
    if (!sent) {
      this.logger.error(`OTP gagal dikirim ke ${dto.phone} (login)`);
      if (!isDev3 && !showOtp3) {
        throw new InternalServerErrorException(
          'Gagal mengirim OTP via WhatsApp. Coba lagi dalam beberapa saat.',
        );
      }
      this.logger.warn(`[DEV] Zenziva gagal, OTP ${otp} disisipkan langsung di response`);
    } else {
      this.logger.log(`OTP berhasil dikirim ke ${dto.phone} (login) | kode: ${otp}`);
    }

    return {
      message: 'OTP telah dikirim',
      ...((isDev3 || showOtp3) && { otp }),
    };
  }

  async refreshToken(userId: string, refreshToken: string) {
    const user = await this.usersRepo.findOne({ where: { id: userId } });
    if (!user || !user.refreshToken) throw new UnauthorizedException('Akses ditolak');

    const isValid = await bcrypt.compare(refreshToken, user.refreshToken);
    if (!isValid) throw new UnauthorizedException('Refresh token tidak valid');

    const tokens = await this.generateTokens(user);
    user.refreshToken = await bcrypt.hash(tokens.refreshToken, 10);
    await this.usersRepo.save(user);

    return { accessToken: tokens.accessToken, refreshToken: tokens.refreshToken };
  }

  async logout(userId: string) {
    await this.usersRepo.update(userId, { refreshToken: null });
    return { message: 'Berhasil logout' };
  }

  async quickLogin(phone: string) {
    const users = await this.usersRepo.find({ where: { phone } });
    if (users.length === 0) {
      throw new NotFoundException('Nomor tidak terdaftar, silakan daftar terlebih dahulu');
    }
    if (users.length > 1) {
      throw new NotFoundException('Nomor ini memiliki beberapa peran, silakan login via OTP');
    }
    const user = users[0];
    if (!user.isVerified || !user.name || !user.role) {
      throw new NotFoundException('Nomor tidak terdaftar, silakan daftar terlebih dahulu');
    }

    const tokens = await this.generateTokens(user);
    user.refreshToken = await bcrypt.hash(tokens.refreshToken, 10);
    await this.usersRepo.save(user);

    return {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      isNewUser: false,
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        role: user.role,
        isVerified: user.isVerified,
      },
    };
  }

  private generateOtp(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
  }

  private async generateTokens(user: User) {
    const payload = { sub: user.id, phone: user.phone, role: user.role };
    const accessToken = this.jwtService.sign(payload);
    const refreshToken = this.jwtService.sign(payload, {
      secret: this.configService.get<string>('JWT_REFRESH_SECRET'),
      expiresIn: this.configService.get('JWT_REFRESH_EXPIRES_IN') as any,
    });
    return { accessToken, refreshToken };
  }
}
