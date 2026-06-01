import {
  Body,
  Controller,
  DefaultValuePipe,
  Delete,
  Get,
  Param,
  ParseFloatPipe,
  Patch,
  Post,
  Put,
  Query,
  Req,
  UseGuards,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { Request } from 'express';
import { UsersService } from './users.service';
import { AuthService } from '../auth/auth.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { CreateAddressDto } from './dto/create-address.dto';
import { SwitchRoleDto } from './dto/switch-role.dto';
import { JwtGuard } from '../auth/guards/jwt.guard';

type JwtReq = Request & { user: { userId: string } };

@ApiTags('Users')
@ApiBearerAuth()
@UseGuards(JwtGuard)
@Controller('users')
export class UsersController {
  constructor(
    private readonly usersService: UsersService,
    private readonly authService: AuthService,
  ) {}

  @ApiOperation({ summary: 'Profil user (dari JWT)' })
  @Get('profile')
  getProfile(@Req() req: JwtReq) {
    return this.usersService.findById(req.user.userId);
  }

  @ApiOperation({ summary: 'Update profil (dari JWT)' })
  @Put('profile')
  updateProfile(@Req() req: JwtReq, @Body() dto: UpdateUserDto) {
    return this.usersService.updateProfile(req.user.userId, dto);
  }

  @ApiOperation({ summary: 'Update profil by ID (PATCH)' })
  @Patch('profile/:id')
  patchProfile(@Param('id') id: string, @Body() dto: UpdateUserDto) {
    return this.usersService.updateProfile(id, dto);
  }

  @ApiOperation({ summary: 'Statistik ringkas penumpang' })
  @Get('stats/:userId')
  getStats(@Param('userId') userId: string) {
    return this.usersService.getStats(userId);
  }

  @ApiOperation({ summary: 'Statistik aktivitas penumpang (dari JWT)' })
  @Get('activity-stats')
  getActivityStats(@Req() req: JwtReq) {
    return this.usersService.getActivityStats(req.user.userId);
  }

  @ApiOperation({ summary: 'Daftar alamat tersimpan' })
  @Get('addresses/:userId')
  getAddresses(@Param('userId') userId: string) {
    return this.usersService.getAddresses(userId);
  }

  @ApiOperation({ summary: 'Tambah alamat tersimpan' })
  @Post('addresses/:userId')
  addAddress(
    @Param('userId') userId: string,
    @Body() dto: CreateAddressDto,
  ) {
    return this.usersService.addAddress(userId, dto);
  }

  @ApiOperation({ summary: 'Hapus alamat tersimpan' })
  @Delete('addresses/:userId/:addressId')
  deleteAddress(
    @Param('userId') userId: string,
    @Param('addressId') addressId: string,
  ) {
    return this.usersService.deleteAddress(userId, addressId);
  }

  @ApiOperation({ summary: 'Daftar notifikasi user' })
  @Get('notifications/:userId')
  getNotifications(@Param('userId') userId: string) {
    return this.usersService.getNotifications(userId);
  }

  @ApiOperation({ summary: 'Tandai semua notifikasi sudah dibaca' })
  @Patch('notifications/:userId/read-all')
  markNotificationsRead(@Param('userId') userId: string) {
    return this.usersService.markNotificationsRead(userId);
  }

  @ApiOperation({ summary: 'Buat notifikasi untuk user' })
  @Post('notifications')
  createNotification(
    @Body() body: { userId: string; title: string; body: string; type?: string },
  ) {
    return this.usersService.createNotification(
      body.userId,
      body.title,
      body.body,
      body.type,
    );
  }

  @ApiOperation({ summary: 'Tandai satu notifikasi sudah dibaca' })
  @Patch('notifications/:id/read')
  markNotificationRead(@Param('id') id: string) {
    return this.usersService.markNotificationRead(id);
  }

  @ApiOperation({ summary: 'Hapus satu notifikasi' })
  @Delete('notifications/:id')
  deleteNotification(@Param('id') id: string) {
    return this.usersService.deleteNotification(id);
  }

  @ApiOperation({ summary: 'Riwayat perjalanan penumpang (enriched)' })
  @Get('history')
  getHistory(@Req() req: JwtReq) {
    return this.usersService.getEnrichedHistory(req.user.userId);
  }

  @ApiOperation({ summary: '3 tujuan terakhir penumpang berdasarkan riwayat' })
  @Get('last-destinations/:userId')
  getLastDestinations(
    @Param('userId') userId: string,
    @Query('lat', new DefaultValuePipe(0), ParseFloatPipe) lat: number,
    @Query('lng', new DefaultValuePipe(0), ParseFloatPipe) lng: number,
  ) {
    return this.usersService.getLastDestinations(userId, lat, lng);
  }

  @ApiOperation({ summary: 'Reverse geocoding nama area dari koordinat GPS' })
  @Get('location-suggestions')
  getLocationSuggestions(
    @Query('lat', new DefaultValuePipe(0), ParseFloatPipe) lat: number,
    @Query('lng', new DefaultValuePipe(0), ParseFloatPipe) lng: number,
  ) {
    return this.usersService.getLocationSuggestions(lat, lng);
  }

  @ApiOperation({ summary: 'Simpan FCM token pengguna (semua role)' })
  @Post('fcm-token')
  updateFcmToken(
    @Req() req: JwtReq,
    @Body() body: { fcmToken: string },
  ) {
    return this.usersService.updateFcmToken(req.user.userId, body.fcmToken);
  }

  @ApiOperation({ summary: 'Switch antara role PASSENGER ↔ DRIVER (akun multi-role)' })
  @Post('switch-role')
  async switchRole(@Req() req: JwtReq, @Body() dto: SwitchRoleDto) {
    const user = await this.usersService.findById(req.user.userId);
    return this.authService.selectRole(user.phone, dto.targetRole);
  }
}
