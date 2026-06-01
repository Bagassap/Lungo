import {
  Controller,
  Get,
  Post,
  Patch,
  Param,
  Query,
  Body,
  UseGuards,
  Req,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { Request } from 'express';
import { AdminService } from './admin.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { AdminGuard } from '../auth/guards/admin.guard';

interface AuthRequest extends Request {
  user?: { sub: string; phone: string; role: string };
}

@UseGuards(JwtAuthGuard, AdminGuard)
@Controller('admin')
export class AdminController {
  constructor(private readonly adminService: AdminService) { }

  @Get('me')
  getProfile(@Req() req: AuthRequest) {
    return this.adminService.getAdminProfile(req.user?.sub ?? '');
  }

  @Get('stats')
  getStats() {
    return this.adminService.getStats();
  }

  @Get('analytics')
  getAnalytics() {
    return this.adminService.getAnalytics();
  }

  @Get('users')
  getUsers(
    @Query('search') search?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.adminService.getUsers(
      search,
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 20,
    );
  }

  @Get('users/:id/detail')
  getPassengerDetail(@Param('id') id: string) {
    return this.adminService.getPassengerDetail(id);
  }

  @Patch('users/:id/status')
  toggleUserStatus(
    @Param('id') id: string,
    @Body('active') active: boolean,
    @Req() req: AuthRequest,
  ) {
    const ip = req.ip ?? req.socket?.remoteAddress;
    return this.adminService.toggleUserStatus(
      id, active,
      req.user?.sub ?? 'unknown',
      req.user?.phone ?? 'Admin',
      ip,
    );
  }

  @Get('drivers')
  getDrivers(@Query('filter') filter?: string) {
    return this.adminService.getDrivers(filter);
  }

  @Get('drivers/:id/report')
  getDriverReport(@Param('id') id: string) {
    return this.adminService.getDriverReport(id);
  }

  @Patch('drivers/:id/verify')
  verifyDriver(
    @Param('id') id: string,
    @Body('approved') approved: boolean,
    @Req() req: AuthRequest,
  ) {
    const ip = req.ip ?? req.socket?.remoteAddress;
    return this.adminService.verifyDriver(
      id, approved,
      req.user?.sub ?? 'unknown',
      req.user?.phone ?? 'Admin',
      ip,
    );
  }

  @Get('tariff')
  getTariff() {
    return this.adminService.getTariff();
  }

  @Patch('tariff')
  updateTariff(
    @Body() dto: { basePrice?: number; pricePerKm?: number; pricePerMinute?: number },
    @Req() req: AuthRequest,
  ) {
    const ip = req.ip ?? req.socket?.remoteAddress;
    return this.adminService.updateTariff(
      dto,
      req.user?.sub ?? 'unknown',
      req.user?.phone ?? 'Admin',
      ip,
    );
  }

  @Get('chats')
  getActiveChats() {
    return this.adminService.getActiveChats();
  }

  @Get('trips')
  getTrips(
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.adminService.getTrips(
      status,
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 20,
    );
  }

  @Get('trips/:id')
  getTripDetail(@Param('id') id: string) {
    return this.adminService.getTripDetail(id);
  }

  @Get('reports/weekly')
  getWeeklyReports(
    @Query('driverId') driverId?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.adminService.getWeeklyReports(
      driverId,
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 20,
    );
  }

  @Post('reports/generate')
  @HttpCode(HttpStatus.OK)
  generateReports() {
    return this.adminService.triggerWeeklyReports();
  }

  @Get('complaints')
  getComplaints(
    @Query('status') status?: string,
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.adminService.getComplaints(
      status,
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 20,
    );
  }

  @Patch('complaints/:id/reply')
  replyComplaint(
    @Param('id') id: string,
    @Body('reply') reply: string,
    @Req() req: AuthRequest,
  ) {
    const ip = req.ip ?? req.socket?.remoteAddress;
    return this.adminService.replyComplaint(
      id, reply,
      req.user?.sub ?? 'unknown',
      req.user?.phone ?? 'Admin',
      ip,
    );
  }

  @Get('audit-logs')
  getAuditLogs(
    @Query('page') page?: string,
    @Query('limit') limit?: string,
  ) {
    return this.adminService.getAuditLogs(
      page ? parseInt(page) : 1,
      limit ? parseInt(limit) : 30,
    );
  }

  @Get('notifications')
  getNotifications(@Query('limit') limit?: string) {
    return this.adminService.getNotifications(limit ? parseInt(limit) : 50);
  }

  @Patch('notifications/read-all')
  markAllNotificationsRead() {
    return this.adminService.markAllNotificationsRead();
  }

  @Patch('notifications/:id/read')
  markNotificationRead(@Param('id') id: string) {
    return this.adminService.markNotificationRead(id);
  }

  @Post('broadcast')
  @HttpCode(HttpStatus.OK)
  broadcast(
    @Body() dto: { role: 'PASSENGER' | 'DRIVER' | 'ALL'; title: string; body: string },
  ) {
    return this.adminService.broadcastNotification(dto.role, dto.title, dto.body);
  }
}

@UseGuards(JwtAuthGuard)
@Controller('complaints')
export class ComplaintController {
  constructor(private readonly adminService: AdminService) { }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  submit(
    @Body() body: {
      driverId?: string;
      rideId?: string;
      type: string;
      subject: string;
      message: string;
    },
    @Req() req: AuthRequest,
  ) {
    return this.adminService.submitComplaint({
      passengerId: req.user!.sub,
      ...body,
    });
  }

  @Get('my')
  myComplaints(@Req() req: AuthRequest) {
    return this.adminService.getPassengerComplaints(req.user!.sub);
  }
}
