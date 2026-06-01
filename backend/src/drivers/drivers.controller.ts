import {
  Body,
  Controller,
  Get,
  Put,
  Post,
  Req,
  UseGuards,
  UseInterceptors,
  UploadedFiles,
  BadRequestException,
} from '@nestjs/common';
import { FileFieldsInterceptor } from '@nestjs/platform-express';
import { diskStorage } from 'multer';
import { extname } from 'path';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiConsumes } from '@nestjs/swagger';
import { Request } from 'express';
import { DriversService } from './drivers.service';
import { UpdateDriverDto } from './dto/update-driver.dto';
import { ToggleOnlineDto } from './dto/toggle-online.dto';
import { DriverSubmitRegistrationDto } from './dto/driver-submit-registration.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';

interface MulterFile {
  fieldname: string;
  originalname: string;
  encoding: string;
  mimetype: string;
  size: number;
  destination: string;
  filename: string;
  path: string;
  buffer: Buffer;
}

@ApiTags('Drivers')
@ApiBearerAuth()
@UseGuards(JwtGuard)
@Controller('drivers')
export class DriversController {
  constructor(private readonly driversService: DriversService) {}

  @Get('profile')
  @ApiOperation({ summary: 'Ambil profil driver' })
  getProfile(@Req() req: Request & { user: { userId: string } }) {
    return this.driversService.getProfile(req.user.userId);
  }

  @Put('profile')
  @ApiOperation({ summary: 'Update profil driver' })
  updateProfile(
    @Req() req: Request & { user: { userId: string } },
    @Body() dto: UpdateDriverDto,
  ) {
    return this.driversService.updateProfile(req.user.userId, dto);
  }

  @Post('toggle-online')
  @ApiOperation({ summary: 'Toggle online/offline driver' })
  toggleOnline(
    @Req() req: Request & { user: { userId: string } },
    @Body() dto: ToggleOnlineDto,
  ) {
    return this.driversService.toggleOnline(req.user.userId, dto);
  }

  @Post('fcm-token')
  @ApiOperation({ summary: 'Simpan FCM token device driver' })
  updateFcmToken(
    @Req() req: Request & { user: { userId: string } },
    @Body('fcmToken') fcmToken: string,
  ) {
    return this.driversService.updateFcmToken(req.user.userId, fcmToken);
  }

  @Post('upload-document')
  @ApiOperation({ summary: 'Upload foto KTP atau SIM' })
  uploadDocument(
    @Req() req: Request & { user: { userId: string } },
    @Body('type') type: 'ktp' | 'sim',
    @Body('fileUrl') fileUrl: string,
  ) {
    return this.driversService.uploadDocument(req.user.userId, type, fileUrl);
  }

  @Post('submit-registration')
  @ApiOperation({ summary: 'Submit registrasi driver lengkap dengan dokumen' })
  @ApiConsumes('multipart/form-data')
  @UseInterceptors(
    FileFieldsInterceptor(
      [
        { name: 'ktp', maxCount: 1 },
        { name: 'sim', maxCount: 1 },
        { name: 'bpkb', maxCount: 1 },
        { name: 'stnk', maxCount: 1 },
      ],
      {
        storage: diskStorage({
          destination: './uploads/drivers',
          filename: (_req, file, cb) => {
            const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
            cb(null, `${file.fieldname}-${uniqueSuffix}${extname(file.originalname)}`);
          },
        }),
        fileFilter: (_req, file, cb) => {
          const allowed = ['image/jpeg', 'image/png', 'image/jpg', 'image/heic'];
          if (allowed.includes(file.mimetype)) {
            cb(null, true);
          } else {
            cb(new BadRequestException('Hanya file gambar yang diizinkan'), false);
          }
        },
        limits: { fileSize: 10 * 1024 * 1024 },
      },
    ),
  )
  async submitRegistration(
    @Req() req: Request & { user: { userId: string } },
    @UploadedFiles()
    files: {
      ktp?: MulterFile[];
      sim?: MulterFile[];
      bpkb?: MulterFile[];
      stnk?: MulterFile[];
    },
    @Body() dto: DriverSubmitRegistrationDto,
  ) {
    const baseUrl = `${req.protocol}://${req.get('host')}`;
    const ktpUrl  = files?.ktp?.[0]  ? `${baseUrl}/uploads/drivers/${files.ktp[0].filename}`  : undefined;
    const simUrl  = files?.sim?.[0]  ? `${baseUrl}/uploads/drivers/${files.sim[0].filename}`  : undefined;
    const bpkbUrl = files?.bpkb?.[0] ? `${baseUrl}/uploads/drivers/${files.bpkb[0].filename}` : undefined;
    const stnkUrl = files?.stnk?.[0] ? `${baseUrl}/uploads/drivers/${files.stnk[0].filename}` : undefined;

    return this.driversService.submitRegistration(req.user.userId, dto, {
      ktpUrl,
      simUrl,
      bpkbUrl,
      stnkUrl,
    });
  }

  @Post('confirm-payment')
  @ApiOperation({ summary: 'Konfirmasi pembayaran pendaftaran driver' })
  confirmPayment(@Req() req: Request & { user: { userId: string } }) {
    return this.driversService.confirmPayment(req.user.userId);
  }

  @Get('registration-status')
  @ApiOperation({ summary: 'Cek status registrasi driver' })
  getRegistrationStatus(@Req() req: Request & { user: { userId: string } }) {
    return this.driversService.getRegistrationStatus(req.user.userId);
  }

  @Get('stats')
  @ApiOperation({ summary: 'Statistik driver' })
  getStats(@Req() req: Request & { user: { userId: string } }) {
    return this.driversService.getDriverStats(req.user.userId);
  }

  @Get('activity-stats')
  @ApiOperation({ summary: 'Statistik aktivitas driver' })
  getActivityStats(@Req() req: Request & { user: { userId: string } }) {
    return this.driversService.getActivityStats(req.user.userId);
  }

  @Get('today-stats')
  @ApiOperation({ summary: 'Statistik hari ini (detail)' })
  getTodayStats(@Req() req: Request & { user: { userId: string } }) {
    return this.driversService.getTodayDetailedStats(req.user.userId);
  }

  @Get('hot-zones')
  @ApiOperation({ summary: 'Zona permintaan tinggi saat ini' })
  getHotZones() {
    return this.driversService.getHotZones();
  }

  @Get('history')
  @ApiOperation({ summary: 'Riwayat trip driver (50 terakhir)' })
  getHistory(@Req() req: Request & { user: { userId: string } }) {
    return this.driversService.getDriverHistory(req.user.userId);
  }

  @Get('active-ride')
  @ApiOperation({ summary: 'Ride aktif driver saat ini' })
  getActiveRide(@Req() req: Request & { user: { userId: string } }) {
    return this.driversService.getActiveRide(req.user.userId);
  }

  @Post('upgrade')
  @ApiOperation({ summary: 'Upgrade akun penumpang menjadi driver' })
  upgradeToDriver(
    @Req() req: Request & { user: { userId: string } },
    @Body('vehiclePlate') vehiclePlate: string,
    @Body('vehicleType') vehicleType: string,
    @Body('ktpNumber') ktpNumber: string,
    @Body('motorSubtype') motorSubtype: string,
  ) {
    return this.driversService.upgradeToDriver(req.user.userId, vehiclePlate, vehicleType, ktpNumber, motorSubtype);
  }
}
