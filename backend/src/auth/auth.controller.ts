import { Body, Controller, Get, Post, Req, UseGuards } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Throttle } from '@nestjs/throttler';
import { Request } from 'express';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { VerifyOtpDto } from './dto/verify-otp.dto';
import { LoginDto } from './dto/login.dto';
import { RefreshDto } from './dto/refresh.dto';
import { SendOtpDto } from './dto/send-otp.dto';
import { CompleteRegistrationDto } from './dto/complete-registration.dto';
import { SelectRoleDto } from './dto/select-role.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';

@ApiTags('Auth')
@Controller('auth')
export class AuthController {
  constructor(
    private readonly authService: AuthService,
    private readonly configService: ConfigService,
  ) {}

  @Post('send-otp')
  @Throttle({ short: { ttl: 60000, limit: 3 }, long: { ttl: 60000, limit: 3 } })
  @ApiOperation({ summary: 'Kirim OTP (unified — works untuk user baru & lama)' })
  sendOtp(@Body() dto: SendOtpDto) {
    return this.authService.sendOtp(dto.phone);
  }

  @Post('complete-registration')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Lengkapi nama & role setelah verifikasi OTP' })
  completeRegistration(
    @Req() req: Request & { user: { userId: string } },
    @Body() dto: CompleteRegistrationDto,
  ) {
    return this.authService.completeRegistration(req.user.userId, dto);
  }

  @Post('register')
  @ApiOperation({ summary: 'Daftarkan user baru (legacy)' })
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Post('verify-otp')
  @Throttle({ short: { ttl: 60000, limit: 5 }, long: { ttl: 60000, limit: 5 } })
  @ApiOperation({ summary: 'Verifikasi OTP dan dapatkan token' })
  verifyOtp(@Body() dto: VerifyOtpDto) {
    return this.authService.verifyOtp(dto);
  }

  @Post('login')
  @Throttle({ short: { ttl: 60000, limit: 5 }, long: { ttl: 60000, limit: 5 } })
  @ApiOperation({ summary: 'Request OTP untuk login (user sudah ada)' })
  login(@Body() dto: LoginDto) {
    return this.authService.login(dto);
  }

  @Post('refresh')
  @Throttle({ short: { ttl: 60000, limit: 10 }, long: { ttl: 60000, limit: 10 } })
  @ApiOperation({ summary: 'Refresh access token' })
  refresh(@Body() dto: RefreshDto) {
    return this.authService.refreshToken(dto.userId, dto.refreshToken);
  }

  @Post('quick-login')
  @Throttle({ short: { ttl: 60000, limit: 5 }, long: { ttl: 60000, limit: 5 } })
  @ApiOperation({ summary: 'Login langsung tanpa OTP untuk nomor terdaftar' })
  quickLogin(@Body() dto: SendOtpDto) {
    return this.authService.quickLogin(dto.phone);
  }

  @Get('verify-token')
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Verifikasi token masih valid' })
  verifyToken(@Req() req: Request & { user?: { sub: string; phone: string; role: string } }) {
    return { valid: true, user: req.user };
  }

  @Post('select-role')
  @ApiOperation({ summary: 'Pilih role setelah verifikasi OTP untuk akun multi-role' })
  selectRole(@Body() dto: SelectRoleDto) {
    return this.authService.selectRole(dto.phone, dto.role, dto.tempToken ?? undefined);
  }

  @Post('logout')
  @ApiBearerAuth()
  @UseGuards(JwtAuthGuard)
  @ApiOperation({ summary: 'Logout user' })
  logout(@Req() req: Request & { user: { userId: string } }) {
    return this.authService.logout(req.user.userId);
  }
}
