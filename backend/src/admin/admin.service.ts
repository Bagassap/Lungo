import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between, In, MoreThanOrEqual } from 'typeorm';
import { Cron, CronExpression } from '@nestjs/schedule';
import { FirebaseService } from '../firebase/firebase.service';
import { User, UserRole } from '../users/entities/user.entity';
import { Ride } from '../booking/entities/ride.entity';
import { Driver } from '../drivers/entities/driver.entity';
import { RideStatus } from '../booking/enums/ride-status.enum';
import { Complaint, ComplaintStatus } from './entities/complaint.entity';
import { WeeklyReport } from './entities/weekly_report.entity';
import { AuditLog } from './entities/audit_log.entity';
import { AdminNotification } from './entities/admin_notification.entity';
import { TariffService } from '../tariff/tariff.service';
import { ChatMessage } from '../chat/entities/chat_message.entity';

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
    @InjectRepository(Ride)
    private readonly rideRepo: Repository<Ride>,
    @InjectRepository(Driver)
    private readonly driverRepo: Repository<Driver>,
    @InjectRepository(Complaint)
    private readonly complaintRepo: Repository<Complaint>,
    @InjectRepository(WeeklyReport)
    private readonly reportRepo: Repository<WeeklyReport>,
    @InjectRepository(AuditLog)
    private readonly auditRepo: Repository<AuditLog>,
    @InjectRepository(AdminNotification)
    private readonly notifRepo: Repository<AdminNotification>,
    @InjectRepository(ChatMessage)
    private readonly chatMsgRepo: Repository<ChatMessage>,
    private readonly tariffService: TariffService,
    private readonly firebaseService: FirebaseService,
  ) {}

  async getAdminProfile(adminId: string) {
    const user = await this.userRepo.findOne({ where: { id: adminId } });
    const [stats, pendingDrivers] = await Promise.all([
      this.getStats(),
      this.driverRepo.count({ where: { registrationStatus: 'PENDING' } }),
    ]);
    return {
      id: user?.id,
      name: user?.name,
      phone: user?.phone,
      role: user?.role,
      createdAt: user?.createdAt,
      stats: { ...stats, pendingDrivers },
    };
  }

  private async _safeCount(fn: () => Promise<number>): Promise<number> {
    try { return await fn(); } catch { return 0; }
  }

  async getStats() {
    const activeStatuses = [RideStatus.SEARCHING, RideStatus.ACCEPTED, RideStatus.PICKUP, RideStatus.ONGOING];
    const [totalUsers, totalDrivers, activeTrips, totalRides, onlineDrivers, pendingVerifications, unreadNotifications] =
      await Promise.all([
        this.userRepo.count({ where: { role: UserRole.PASSENGER } }),
        this.driverRepo.count(),
        this.rideRepo.count({ where: { status: In(activeStatuses) } }),
        this.rideRepo.count({ where: { status: RideStatus.DONE } }),
        this.driverRepo.count({ where: { isOnline: true } }),
        this.driverRepo.count({ where: { registrationStatus: 'PAYMENT_PENDING' } }),
        this._safeCount(() => this.notifRepo.count({ where: { isRead: false } })),
      ]);

    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);

    const [todayRaw, weekRaw, monthRaw] = await Promise.all([
      this.rideRepo
        .createQueryBuilder('r')
        .select('SUM(r.fare)', 'total')
        .where('r.status = :s', { s: RideStatus.DONE })
        .andWhere('r.updatedAt >= :start', { start: todayStart })
        .getRawOne(),
      this._revenueFrom(this._daysAgo(7)),
      this._revenueFrom(this._daysAgo(30)),
    ]);

    const openComplaints = await this._safeCount(() =>
      this.complaintRepo.count({ where: { status: ComplaintStatus.OPEN } }),
    );

    return {
      totalUsers,
      totalDrivers,
      activeTrips,
      totalRides,
      onlineDrivers,
      todayRevenue: parseFloat(todayRaw?.total ?? '0') || 0,
      weekRevenue: parseFloat(weekRaw?.total ?? '0') || 0,
      monthRevenue: parseFloat(monthRaw?.total ?? '0') || 0,
      openComplaints,
      pendingVerifications,
      unreadNotifications,
    };
  }

  async createNotification(type: string, title: string, body: string, targetId?: string) {
    await this.notifRepo.save(
      this.notifRepo.create({ type, title, body, targetId: targetId ?? null }),
    );
  }

  async getNotifications(limit = 50) {
    return this.notifRepo.find({
      order: { createdAt: 'DESC' },
      take: limit,
    });
  }

  async markNotificationRead(id: string) {
    await this.notifRepo.update(id, { isRead: true });
    return { ok: true };
  }

  async markAllNotificationsRead() {
    await this.notifRepo.update({ isRead: false }, { isRead: true });
    return { ok: true };
  }

  async broadcastNotification(
    role: 'PASSENGER' | 'DRIVER' | 'ALL',
    title: string,
    body: string,
  ): Promise<{ sent: number }> {
    const roles = role === 'ALL' ? ['PASSENGER', 'DRIVER'] : [role];

    const users = await this.userRepo
      .createQueryBuilder('u')
      .select('u.fcmToken')
      .where('u.role IN (:...roles)', { roles })
      .andWhere('u.fcmToken IS NOT NULL')
      .getMany();

    const tokens = users.map((u) => u.fcmToken).filter(Boolean) as string[];

    const CHUNK = 500;
    for (let i = 0; i < tokens.length; i += CHUNK) {
      await this.firebaseService.sendMulticast(tokens.slice(i, i + CHUNK), title, body, {
        type: 'ADMIN_BROADCAST',
      });
    }

    await this.notifRepo.save(
      this.notifRepo.create({
        type: 'ADMIN_BROADCAST',
        title: `[Broadcast ${role}] ${title}`,
        body,
      }),
    );

    return { sent: tokens.length };
  }

  async getAnalytics() {
    const days: { date: string; revenue: number; rides: number }[] = [];
    for (let i = 29; i >= 0; i--) {
      const start = this._daysAgo(i);
      const end   = new Date(start);
      end.setDate(end.getDate() + 1);
      const row = await this.rideRepo
        .createQueryBuilder('r')
        .select('SUM(r.fare)', 'revenue')
        .addSelect('COUNT(r.id)', 'rides')
        .where('r.status = :s', { s: RideStatus.DONE })
        .andWhere('r.updatedAt >= :start', { start })
        .andWhere('r.updatedAt < :end', { end })
        .getRawOne();
      days.push({
        date: start.toISOString().slice(0, 10),
        revenue: parseFloat(row?.revenue ?? '0') || 0,
        rides: parseInt(row?.rides ?? '0') || 0,
      });
    }
    return { days };
  }

  async getUsers(search?: string, page = 1, limit = 20) {
    const qb = this.userRepo
      .createQueryBuilder('u')
      .select(['u.id', 'u.phone', 'u.name', 'u.role', 'u.isVerified', 'u.createdAt', 'u.updatedAt'])
      .where('u.role != :role', { role: UserRole.ADMIN });
    if (search) {
      qb.andWhere('(u.name ILIKE :s OR u.phone ILIKE :s)', {
        s: `%${search}%`,
      });
    }
    const [users, total] = await qb
      .orderBy('u.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();
    return { users, total, page, limit };
  }

  async toggleUserStatus(
    id: string,
    active: boolean,
    adminId: string,
    adminName: string,
    ip?: string,
  ) {
    await this.userRepo.update(id, { isVerified: active });
    await this.logAudit({
      adminId,
      adminName,
      action: 'TOGGLE_USER_STATUS',
      details: `Set isVerified=${active}`,
      targetId: id,
      targetType: 'USER',
      ipAddress: ip,
    });
    return this.userRepo.findOneOrFail({ where: { id } });
  }

  async getDrivers(filter?: string) {
    const qb = this.driverRepo.createQueryBuilder('d');
    if (filter === 'online') qb.where('d.isOnline = true');
    else if (filter === 'offline') qb.where('d.isOnline = false');
    else if (filter === 'pending')
      qb.where('d.registrationStatus = :s', { s: 'PENDING' });
    else if (filter === 'payment_pending')
      qb.where('d.registrationStatus = :s', { s: 'PAYMENT_PENDING' });
    else if (filter === 'verified')
      qb.where('d.registrationStatus = :s', { s: 'APPROVED' });

    const drivers = await qb.orderBy('d.createdAt', 'DESC').getMany();

    const userIds = [...new Set(drivers.map((d) => d.userId))];
    const users = userIds.length
      ? await this.userRepo
          .createQueryBuilder('u')
          .select(['u.id', 'u.phone', 'u.name', 'u.role', 'u.isVerified', 'u.createdAt'])
          .where('u.id IN (:...ids)', { ids: userIds })
          .getMany()
      : [];
    const userMap = Object.fromEntries(users.map((u) => [u.id, u]));
    return drivers.map((d) => ({ ...d, user: userMap[d.userId] ?? null }));
  }

  async verifyDriver(
    id: string,
    approved: boolean,
    adminId: string,
    adminName: string,
    ip?: string,
  ) {
    const status = approved ? 'APPROVED' : 'REJECTED';
    await this.driverRepo.update(id, { registrationStatus: status });
    await this.logAudit({
      adminId,
      adminName,
      action: 'VERIFY_DRIVER',
      details: `registrationStatus set to ${status}`,
      targetId: id,
      targetType: 'DRIVER',
      ipAddress: ip,
    });
    return this.driverRepo.findOneOrFail({ where: { id } });
  }

  async getPassengerDetail(userId: string) {
    const user = await this.userRepo.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');

    const [totalRides, completedRides, cancelledRides] = await Promise.all([
      this.rideRepo.count({ where: { passengerId: userId } }),
      this.rideRepo.count({ where: { passengerId: userId, status: RideStatus.DONE } }),
      this.rideRepo.count({ where: { passengerId: userId, status: RideStatus.CANCELLED } }),
    ]);

    const spentRaw = await this.rideRepo
      .createQueryBuilder('r')
      .select('SUM(r.fare)', 'total')
      .where('r.passengerId = :userId', { userId })
      .andWhere('r.status = :s', { s: RideStatus.DONE })
      .getRawOne();
    const totalSpent = parseFloat(spentRaw?.total ?? '0') || 0;

    const recentRides = await this.rideRepo.find({
      where: { passengerId: userId },
      order: { createdAt: 'DESC' },
      take: 10,
    });

    return {
      user,
      stats: { totalRides, completedRides, cancelledRides, totalSpent },
      recentRides,
    };
  }

  async getDriverReport(driverRecordId: string) {

    const driver = await this.driverRepo.findOne({ where: { id: driverRecordId } });
    if (!driver) throw new NotFoundException('Driver not found');
    const user = await this.userRepo.findOne({ where: { id: driver.userId } });
    if (!user) throw new NotFoundException('Driver user not found');

    const userId = driver.userId;
    const [totalRides, completedRides, cancelledRides] = await Promise.all([
      this.rideRepo.count({ where: { driverId: userId } }),
      this.rideRepo.count({ where: { driverId: userId, status: RideStatus.DONE } }),
      this.rideRepo.count({ where: { driverId: userId, status: RideStatus.CANCELLED } }),
    ]);

    const earningsRaw = await this.rideRepo
      .createQueryBuilder('r')
      .select('SUM(r.fare)', 'total')
      .where('r.driverId = :userId', { userId })
      .andWhere('r.status = :s', { s: RideStatus.DONE })
      .getRawOne();
    const totalEarnings = parseFloat(earningsRaw?.total ?? '0') || 0;

    const weeks = await this.reportRepo.find({
      where: { driverId: userId },
      order: { weekStart: 'DESC' },
      take: 4,
    });

    const recentRides = await this.rideRepo.find({
      where: { driverId: userId },
      order: { createdAt: 'DESC' },
      take: 10,
    });

    return {
      user,
      driver,
      stats: { totalRides, completedRides, cancelledRides, totalEarnings },
      weeklyReports: weeks,
      recentRides,
    };
  }

  async getActiveTrips() {
    const activeStatuses = [RideStatus.SEARCHING, RideStatus.ACCEPTED, RideStatus.PICKUP, RideStatus.ONGOING];
    const rides = await this.rideRepo.find({
      where: { status: In(activeStatuses) },
      order: { createdAt: 'DESC' },
    });

    const isUuid = (v: unknown) => typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
    const pIds = [...new Set(rides.map((r) => r.passengerId).filter(isUuid))];
    const dIds = [...new Set(rides.map((r) => r.driverId).filter(isUuid))] as string[];
    const allIds = [...new Set([...pIds, ...dIds])];
    const users = allIds.length
      ? await this.userRepo.createQueryBuilder('u').where('u.id IN (:...ids)', { ids: allIds }).getMany()
      : [];
    const uMap = Object.fromEntries(users.map((u) => [u.id, u]));

    return rides.map((r) => ({
      id: r.id,
      passengerName: uMap[r.passengerId]?.name ?? '-',
      driverName: r.driverId ? (uMap[r.driverId]?.name ?? '-') : '-',
      originAddress: r.originAddress,
      destinationAddress: r.destinationAddress,
      fare: r.fare,
      status: r.status,
      createdAt: r.createdAt,
    }));
  }

  async getRevenueChart() {
    const now = new Date();
    const result: { day: string; date: string; revenue: number; tripCount: number }[] = [];

    for (let i = 6; i >= 0; i--) {
      const d = new Date(now);
      d.setDate(d.getDate() - i);
      const start = new Date(d); start.setHours(0, 0, 0, 0);
      const end   = new Date(d); end.setHours(23, 59, 59, 999);

      const row = await this.rideRepo
        .createQueryBuilder('r')
        .select('SUM(r.fare)', 'revenue')
        .addSelect('COUNT(r.id)', 'rides')
        .where('r.status = :s', { s: RideStatus.DONE })
        .andWhere('r.updatedAt >= :start', { start })
        .andWhere('r.updatedAt <= :end',   { end })
        .getRawOne();

      const dayNames = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];
      result.push({
        day:       dayNames[start.getDay()],
        date:      start.toISOString().split('T')[0],
        revenue:   parseFloat(row?.revenue ?? '0') || 0,
        tripCount: parseInt(row?.rides    ?? '0') || 0,
      });
    }

    const prevStart = new Date(now); prevStart.setDate(prevStart.getDate() - 14); prevStart.setHours(0, 0, 0, 0);
    const prevEnd   = new Date(now); prevEnd.setDate(prevEnd.getDate() - 7);      prevEnd.setHours(23, 59, 59, 999);
    const prevRow   = await this.rideRepo
      .createQueryBuilder('r')
      .select('SUM(r.fare)', 'total')
      .where('r.status = :s', { s: RideStatus.DONE })
      .andWhere('r.updatedAt >= :start', { start: prevStart })
      .andWhere('r.updatedAt <= :end',   { end: prevEnd })
      .getRawOne();

    const thisWeek = result.reduce((s, r) => s + r.revenue, 0);
    const prevWeek = parseFloat(prevRow?.total ?? '0') || 0;
    const growth   = prevWeek > 0
      ? parseFloat(((thisWeek - prevWeek) / prevWeek * 100).toFixed(1))
      : (thisWeek > 0 ? 100 : 0);

    return { days: result, growth };
  }

  async getRevenue(period = 'month') {
    const now = new Date();
    let startDate: Date;
    let endDate: Date | undefined;

    switch (period) {
      case 'today':
        startDate = new Date(now);
        startDate.setHours(0, 0, 0, 0);
        break;
      case 'week':
        startDate = this._daysAgo(7);
        break;
      case 'last_month': {
        const y = now.getMonth() === 0 ? now.getFullYear() - 1 : now.getFullYear();
        const m = now.getMonth() === 0 ? 11 : now.getMonth() - 1;
        startDate = new Date(y, m, 1, 0, 0, 0, 0);
        endDate   = new Date(now.getFullYear(), now.getMonth(), 0, 23, 59, 59, 999);
        break;
      }
      case 'month':
      default:
        startDate = new Date(now.getFullYear(), now.getMonth(), 1, 0, 0, 0, 0);
    }

    const qb = this.rideRepo.createQueryBuilder('r')
      .where('r.status = :s', { s: RideStatus.DONE });
    if (endDate) {
      qb.andWhere('r.updatedAt BETWEEN :start AND :end', { start: startDate, end: endDate });
    } else {
      qb.andWhere('r.updatedAt >= :start', { start: startDate });
    }
    const doneRides = await qb.orderBy('r.updatedAt', 'DESC').getMany();

    if (!doneRides.length) return [];

    const isUuid = (v: unknown) => typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
    const driverIds = [...new Set(doneRides.map((r) => r.driverId).filter(isUuid))] as string[];
    const pIds      = [...new Set(doneRides.map((r) => r.passengerId).filter(isUuid))];
    const allIds    = [...new Set([...driverIds, ...pIds])];
    const users     = allIds.length
      ? await this.userRepo.createQueryBuilder('u').where('u.id IN (:...ids)', { ids: allIds }).getMany()
      : [];
    const uMap = Object.fromEntries(users.map((u) => [u.id, u]));

    const byDriver: Record<string, {
      driverId: string; driverName: string; driverPhone: string;
      totalRevenue: number; totalTrips: number;
      trips: { rideId: string; passengerName: string; fare: number; distanceKm: number; completedAt: string; originAddress: string; destinationAddress: string }[];
    }> = {};

    for (const r of doneRides) {
      if (!r.driverId || !isUuid(r.driverId)) continue;
      const dId = r.driverId;
      if (!byDriver[dId]) {
        byDriver[dId] = {
          driverId: dId,
          driverName: uMap[dId]?.name ?? '-',
          driverPhone: uMap[dId]?.phone ?? '-',
          totalRevenue: 0,
          totalTrips: 0,
          trips: [],
        };
      }
      const fare = parseFloat(r.fare as any) || 0;
      byDriver[dId].totalRevenue += fare;
      byDriver[dId].totalTrips++;
      const completedAt = r.updatedAt ?? r.createdAt;
      byDriver[dId].trips.push({
        rideId: r.id,
        passengerName: uMap[r.passengerId]?.name ?? '-',
        fare,
        distanceKm: parseFloat(r.distanceKm as any) || 0,
        completedAt: completedAt?.toISOString() ?? '',
        originAddress: r.originAddress ?? '',
        destinationAddress: r.destinationAddress ?? '',
      });
    }

    return Object.values(byDriver).sort((a, b) => b.totalRevenue - a.totalRevenue);
  }

  async getTripsByDriver() {
    const rides = await this.rideRepo
      .createQueryBuilder('r')
      .where('r.status != :s', { s: RideStatus.SEARCHING })
      .orderBy('r.createdAt', 'DESC')
      .getMany();

    if (!rides.length) return [];

    const isUuid = (v: unknown) => typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
    const pIds   = [...new Set(rides.map((r) => r.passengerId).filter(isUuid))];
    const dIds   = [...new Set(rides.map((r) => r.driverId).filter(isUuid))] as string[];
    const allIds = [...new Set([...pIds, ...dIds])];
    const users  = allIds.length
      ? await this.userRepo.createQueryBuilder('u').where('u.id IN (:...ids)', { ids: allIds }).getMany()
      : [];
    const uMap = Object.fromEntries(users.map((u) => [u.id, u]));

    const groups: Record<string, {
      driverId: string; driverName: string;
      totalTrips: number; totalRevenue: number;
      trips: { id: string; passengerName: string; originAddress: string; destinationAddress: string; status: string; fare: number; distanceKm: number; createdAt: Date; updatedAt: Date }[];
    }> = {};

    for (const r of rides) {
      const dId   = r.driverId ?? 'no-driver';
      const dName = r.driverId ? (uMap[r.driverId]?.name ?? 'Driver Tidak Diketahui') : 'Tanpa Driver';
      if (!groups[dId]) {
        groups[dId] = { driverId: dId, driverName: dName, totalTrips: 0, totalRevenue: 0, trips: [] };
      }
      groups[dId].totalTrips++;
      if (r.status === RideStatus.DONE) {
        groups[dId].totalRevenue += parseFloat(r.fare as any) || 0;
      }
      groups[dId].trips.push({
        id: r.id,
        passengerName: uMap[r.passengerId]?.name ?? '-',
        originAddress: r.originAddress ?? '-',
        destinationAddress: r.destinationAddress ?? '-',
        status: r.status,
        fare: parseFloat(r.fare as any) || 0,
        distanceKm: parseFloat(r.distanceKm as any) || 0,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      });
    }

    return Object.values(groups).sort((a, b) => b.totalTrips - a.totalTrips);
  }

  async getTrips(status?: string, page = 1, limit = 20) {
    const qb = this.rideRepo.createQueryBuilder('r');
    if (status && status !== 'ALL') qb.where('r.status = :status', { status });
    const [rides, total] = await qb
      .orderBy('r.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();

    const isUuid = (v: unknown) => typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
    const pIds = [...new Set(rides.map((r) => r.passengerId).filter(isUuid))];
    const dIds = [...new Set(rides.map((r) => r.driverId).filter(isUuid))] as string[];
    const allIds = [...new Set([...pIds, ...dIds])];
    const users = allIds.length
      ? await this.userRepo
          .createQueryBuilder('u')
          .where('u.id IN (:...ids)', { ids: allIds })
          .getMany()
      : [];
    const uMap = Object.fromEntries(users.map((u) => [u.id, u]));
    return {
      rides: rides.map((r) => ({
        ...r,
        passengerName: uMap[r.passengerId]?.name ?? '-',
        driverName: r.driverId ? (uMap[r.driverId]?.name ?? '-') : '-',
      })),
      total,
      page,
      limit,
    };
  }

  async getActiveChats() {
    const activeStatuses = [
      RideStatus.SEARCHING, RideStatus.ACCEPTED,
      RideStatus.PICKUP,    RideStatus.ONGOING,
    ];
    const rides = await this.rideRepo.find({
      where: { status: In(activeStatuses) },
      order: { createdAt: 'DESC' },
      take: 50,
    });
    if (!rides.length) return [];

    const isUuid = (v: unknown) => typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
    const uIds = [...new Set([
      ...rides.map((r) => r.passengerId).filter(isUuid),
      ...rides.map((r) => r.driverId).filter(isUuid) as string[],
    ])];
    const users = uIds.length
      ? await this.userRepo.createQueryBuilder('u').where('u.id IN (:...ids)', { ids: uIds }).getMany()
      : [];
    const uMap = Object.fromEntries(users.map((u) => [u.id, u]));

    const rideIds = rides.map((r) => r.id);
    const msgs = rideIds.length
      ? await this.chatMsgRepo.find({ where: { rideId: In(rideIds) }, order: { createdAt: 'DESC' } })
      : [];
    const lastMsgMap: Record<string, ChatMessage> = {};
    const unreadMap: Record<string, number> = {};
    for (const m of msgs) {
      if (!lastMsgMap[m.rideId]) lastMsgMap[m.rideId] = m;
      if (!m.isRead) unreadMap[m.rideId] = (unreadMap[m.rideId] ?? 0) + 1;
    }

    return rides.map((r) => ({
      rideId:        r.id,
      passengerName: uMap[r.passengerId]?.name ?? '-',
      driverName:    r.driverId ? (uMap[r.driverId]?.name ?? '-') : '-',
      lastMsg:       lastMsgMap[r.id]?.message ?? '',
      lastMsgAt:     lastMsgMap[r.id]?.createdAt?.toISOString() ?? r.createdAt?.toISOString(),
      unread:        unreadMap[r.id] ?? 0,
      status:        r.status,
    }));
  }

  async getTariff() {
    const [config, history] = await Promise.all([
      this.tariffService.getTariffConfig(),
      this.tariffService.getHistory(20),
    ]);
    return {
      basePrice:      Number(config.basePrice),
      pricePerKm:     Number(config.pricePerKm),
      pricePerMinute: Number(config.pricePerMinute),
      minimumFare:    Number(config.minimumFare),
      updatedAt:      config.updatedAt,
      updatedBy:      config.updatedBy,
      history: history.map((h) => ({
        date:      h.createdAt.toISOString().slice(0, 10),
        change:    h.change,
        adminName: h.adminName,
      })),
    };
  }

  async updateTariff(
    dto: { basePrice?: number; pricePerKm?: number; pricePerMinute?: number },
    adminId: string,
    adminName: string,
    ip?: string,
  ) {
    const { config, changes } = await this.tariffService.persistUpdate(dto, adminId, adminName);

    if (changes.length > 0) {
      await this.logAudit({
        adminId,
        adminName,
        action: 'UPDATE_TARIFF',
        details: changes.join('; '),
        targetType: 'TARIFF',
        ipAddress: ip,
      });
    }

    return {
      basePrice:      Number(config.basePrice),
      pricePerKm:     Number(config.pricePerKm),
      pricePerMinute: Number(config.pricePerMinute),
      minimumFare:    Number(config.minimumFare),
      updatedAt:      config.updatedAt,
      updatedBy:      config.updatedBy,
      changes,
    };
  }

  async getTripDetail(id: string) {
    const ride = await this.rideRepo.findOne({ where: { id } });
    if (!ride) throw new NotFoundException('Ride not found');
    const [passenger, driver] = await Promise.all([
      this.userRepo.findOne({ where: { id: ride.passengerId } }),
      ride.driverId
        ? this.userRepo.findOne({ where: { id: ride.driverId } })
        : null,
    ]);
    return { ...ride, passenger, driver };
  }

  async getWeeklyReport() {
    const now   = new Date();
    const start = new Date(now);
    start.setDate(now.getDate() - 7);
    start.setHours(0, 0, 0, 0);

    const rides = await this.rideRepo
      .createQueryBuilder('r')
      .where('r.createdAt >= :start', { start })
      .orderBy('r.createdAt', 'DESC')
      .getMany();

    if (!rides.length) return {
      period: { start: start.toISOString(), end: now.toISOString() },
      summary: { totalTrips: 0, completedTrips: 0, cancelledTrips: 0, totalRevenue: 0, completionRate: 0 },
      trips: [],
    };

    const isUuid = (v: unknown) => typeof v === 'string' && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(v);
    const pIds   = [...new Set(rides.map(r => r.passengerId).filter(isUuid))];
    const dIds   = [...new Set(rides.map(r => r.driverId).filter(isUuid))] as string[];
    const allIds = [...new Set([...pIds, ...dIds])];
    const users  = allIds.length
      ? await this.userRepo.createQueryBuilder('u').where('u.id IN (:...ids)', { ids: allIds }).getMany()
      : [];
    const uMap = Object.fromEntries(users.map(u => [u.id, u]));

    const done      = rides.filter(r => r.status === RideStatus.DONE);
    const cancelled = rides.filter(r => r.status === RideStatus.CANCELLED);
    const totalRevenue = done.reduce((s, r) => s + (parseFloat(r.fare as any) || 0), 0);

    return {
      period: { start: start.toISOString(), end: now.toISOString() },
      summary: {
        totalTrips:     rides.length,
        completedTrips: done.length,
        cancelledTrips: cancelled.length,
        totalRevenue,
        completionRate: rides.length > 0 ? Math.round(done.length / rides.length * 100) : 0,
      },
      trips: rides.map(r => ({
        id:                 r.id,
        passengerName:      uMap[r.passengerId]?.name ?? '-',
        driverName:         r.driverId ? (uMap[r.driverId]?.name ?? '-') : '-',
        originAddress:      r.originAddress ?? '-',
        destinationAddress: r.destinationAddress ?? '-',
        status:             r.status,
        fare:               parseFloat(r.fare as any) || 0,
        distanceKm:         parseFloat(r.distanceKm as any) || 0,
        createdAt:          r.createdAt,
      })),
    };
  }

  async getWeeklyReports(driverId?: string, page = 1, limit = 20) {
    const qb = this.reportRepo.createQueryBuilder('r');
    if (driverId) qb.where('r.driverId = :driverId', { driverId });
    const [reports, total] = await qb
      .orderBy('r.weekStart', 'DESC')
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();
    return { reports, total, page, limit };
  }

  @Cron(CronExpression.EVERY_WEEK)
  async generateWeeklyReports() {
    const weekEnd   = new Date();
    weekEnd.setHours(0, 0, 0, 0);
    const weekStart = new Date(weekEnd);
    weekStart.setDate(weekStart.getDate() - 7);

    const drivers = await this.userRepo.find({ where: { role: UserRole.DRIVER } });

    for (const user of drivers) {
      const driverId = user.id;

      const rides = await this.rideRepo.find({
        where: {
          driverId,
          createdAt: Between(weekStart, weekEnd),
        },
      });

      const completed = rides.filter((r) => r.status === RideStatus.DONE);
      const cancelled = rides.filter((r) => r.status === RideStatus.CANCELLED);
      const totalEarnings = completed.reduce(
        (s, r) => s + (parseFloat(r.fare as any) || 0),
        0,
      );
      const totalDistanceKm = completed.reduce(
        (s, r) => s + (parseFloat(r.distanceKm as any) || 0),
        0,
      );

      const daily: Record<string, { rides: number; earnings: number }> = {};
      for (const ride of completed) {
        const key = ride.createdAt.toISOString().slice(0, 10);
        if (!daily[key]) daily[key] = { rides: 0, earnings: 0 };
        daily[key].rides++;
        daily[key].earnings += parseFloat(ride.fare as any) || 0;
      }

      const driverProfile = await this.driverRepo.findOne({
        where: { userId: driverId },
      });

      await this.reportRepo.save(
        this.reportRepo.create({
          driverId,
          driverName: user.name ?? 'Unknown',
          weekStart,
          weekEnd,
          totalRides: rides.length,
          completedRides: completed.length,
          cancelledRides: cancelled.length,
          totalEarnings,
          avgRating: driverProfile?.rating ?? null,
          totalDistanceKm,
          dailyBreakdown: daily,
        }),
      );
    }
  }

  async triggerWeeklyReports() {
    await this.generateWeeklyReports();
    return { message: 'Weekly reports generated' };
  }

  async getComplaints(status?: string, page = 1, limit = 20) {
    const qb = this.complaintRepo.createQueryBuilder('c');
    if (status) qb.where('c.status = :status', { status });
    const [complaints, total] = await qb
      .orderBy('c.createdAt', 'DESC')
      .skip((page - 1) * limit)
      .take(limit)
      .getManyAndCount();

    const passengerIds = [...new Set(complaints.map((c) => c.passengerId))];
    const users = passengerIds.length
      ? await this.userRepo
          .createQueryBuilder('u')
          .where('u.id IN (:...ids)', { ids: passengerIds })
          .getMany()
      : [];
    const userMap = Object.fromEntries(users.map((u) => [u.id, u]));
    return {
      complaints: complaints.map((c) => ({
        ...c,
        passengerName: userMap[c.passengerId]?.name ?? '-',
        passengerPhone: userMap[c.passengerId]?.phone ?? '-',
      })),
      total,
      page,
      limit,
    };
  }

  async replyComplaint(
    id: string,
    reply: string,
    adminId: string,
    adminName: string,
    ip?: string,
  ) {
    const c = await this.complaintRepo.findOne({ where: { id } });
    if (!c) throw new NotFoundException('Complaint not found');
    await this.complaintRepo.update(id, {
      adminReply: reply,
      status: ComplaintStatus.RESOLVED,
      repliedBy: adminId,
      repliedAt: new Date(),
    });
    await this.logAudit({
      adminId,
      adminName,
      action: 'REPLY_COMPLAINT',
      details: reply.slice(0, 100),
      targetId: id,
      targetType: 'COMPLAINT',
      ipAddress: ip,
    });
    return this.complaintRepo.findOneOrFail({ where: { id } });
  }

  async submitComplaint(data: {
    passengerId: string;
    driverId?: string;
    rideId?: string;
    type: string;
    subject: string;
    message: string;
  }) {
    const complaint = this.complaintRepo.create({
      passengerId: data.passengerId,
      driverId:    data.driverId   ?? null,
      rideId:      data.rideId     ?? null,
      type:        data.type as any,
      subject:     data.subject,
      message:     data.message,
    });
    return this.complaintRepo.save(complaint);
  }

  async getPassengerComplaints(passengerId: string) {
    return this.complaintRepo.find({
      where: { passengerId },
      order: { createdAt: 'DESC' },
    });
  }

  async logAudit(data: {
    adminId: string;
    adminName: string;
    action: string;
    details?: string;
    targetId?: string;
    targetType?: string;
    ipAddress?: string;
  }) {
    await this.auditRepo.save(this.auditRepo.create(data));
  }

  async getAuditLogs(page = 1, limit = 30) {
    const [logs, total] = await this.auditRepo.findAndCount({
      order: { createdAt: 'DESC' },
      skip: (page - 1) * limit,
      take: limit,
    });
    return { logs, total, page, limit };
  }

  private _daysAgo(n: number): Date {
    const d = new Date();
    d.setDate(d.getDate() - n);
    d.setHours(0, 0, 0, 0);
    return d;
  }

  private async _revenueFrom(since: Date) {
    return this.rideRepo
      .createQueryBuilder('r')
      .select('SUM(r.fare)', 'total')
      .where('r.status = :s', { s: RideStatus.DONE })
      .andWhere('r.updatedAt >= :start', { start: since })
      .getRawOne();
  }
}
