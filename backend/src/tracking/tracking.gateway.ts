import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  MessageBody,
  ConnectedSocket,
  OnGatewayConnection,
  OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { InjectRepository } from '@nestjs/typeorm';
import { In, MoreThan, Repository } from 'typeorm';
import { RedisService } from './redis.service';
import { TrackingService } from './tracking.service';
import { TariffService } from '../tariff/tariff.service';
import { UserNotification } from '../users/entities/user_notification.entity';
import { Ride } from '../booking/entities/ride.entity';
import { RideStatus } from '../booking/enums/ride-status.enum';
import { User } from '../users/entities/user.entity';

interface ActiveRide {
  driverId: string;
  startTime: number;
  prevLat: number;
  prevLng: number;
  totalDistanceKm: number;
}

@WebSocketGateway({ namespace: '/tracking', cors: { origin: '*' } })
export class TrackingGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server: Server;

  private readonly activeRides = new Map<string, ActiveRide>();
  private readonly clientToDriver = new Map<string, string>();

  constructor(
    private readonly redisService: RedisService,
    private readonly trackingService: TrackingService,
    private readonly tariffService: TariffService,
    @InjectRepository(UserNotification)
    private readonly notifRepo: Repository<UserNotification>,
    @InjectRepository(Ride)
    private readonly rideRepo: Repository<Ride>,
    @InjectRepository(User)
    private readonly userRepo: Repository<User>,
  ) {}

  handleConnection(client: Socket) {
    console.log(`[Tracking] Client connected: ${client.id}`);
  }

  handleDisconnect(client: Socket) {
    console.log(`[Tracking] Client disconnected: ${client.id}`);
    const driverId = this.clientToDriver.get(client.id);
    if (driverId) {
      this.clientToDriver.delete(client.id);
      this.redisService.deleteDriverLocation(driverId).catch(() => {});
      this.server.emit('driverStatusChanged', { driverId, status: 'offline' });
    }
  }

  // Client joins a specific ride room to receive scoped events
  @SubscribeMessage('joinRide')
  async handleJoinRide(
    @MessageBody() data: { rideId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const room = `ride:${data.rideId}`;
    client.join(room);
    console.log(`[Tracking] ${client.id} joined room ${room}`);

    // Kirim posisi passenger terakhir dari Redis ke client yang baru join (driver reconnect)
    try {
      const lastPos = await this.redisService.getPassengerLocation(data.rideId);
      if (lastPos) {
        client.emit('passengerLocationUpdated', {
          rideId: data.rideId,
          latitude: lastPos.latitude,
          longitude: lastPos.longitude,
        });
        console.log(`[Tracking] sent last passenger pos to ${client.id} for ride ${data.rideId}`);
      }
    } catch (_) {}

    return { status: 'joined', room };
  }

  @SubscribeMessage('leaveRide')
  handleLeaveRide(
    @MessageBody() data: { rideId: string },
    @ConnectedSocket() client: Socket,
  ) {
    const room = `ride:${data.rideId}`;
    client.leave(room);
    return { status: 'left', room };
  }

  @SubscribeMessage('updateLocation')
  async handleUpdateLocation(
    @MessageBody()
    data: {
      driverId: string;
      latitude: number;
      longitude: number;
      rideId?: string;
    },
    @ConnectedSocket() _client: Socket,
  ) {
    await this.redisService.setDriverLocation(data.driverId, data.latitude, data.longitude);

    const locationPayload = {
      driverId: data.driverId,
      latitude: data.latitude,
      longitude: data.longitude,
      timestamp: new Date().toISOString(),
    };

    if (data.rideId) {
      // Scoped to ride room only — passenger sees driver moving
      this.server.to(`ride:${data.rideId}`).emit('driverLocationUpdated', locationPayload);

      const ride = this.activeRides.get(data.rideId);
      if (ride) {
        const distIncrement = this.trackingService.haversine(
          ride.prevLat, ride.prevLng,
          data.latitude, data.longitude,
        );
        ride.totalDistanceKm += distIncrement;
        ride.prevLat = data.latitude;
        ride.prevLng = data.longitude;

        const durationSeconds = Math.floor((Date.now() - ride.startTime) / 1000);
        const durationMinutes = durationSeconds / 60;
        const fare = this.tariffService.getRealtimeFare(ride.totalDistanceKm, durationMinutes);

        // Broadcast meter update to ride room (both passenger and driver)
        this.server.to(`ride:${data.rideId}`).emit('meter_update', {
          rideId: data.rideId,
          distance_km: Math.round(ride.totalDistanceKm * 100) / 100,
          fare,
          duration_seconds: durationSeconds,
          status: 'ONGOING',
        });

        // Keep legacy argoUpdate for backward compat
        this.server.to(`ride:${data.rideId}`).emit('argoUpdate', {
          rideId: data.rideId,
          distanceKm: Math.round(ride.totalDistanceKm * 100) / 100,
          durationMinutes: Math.round(durationMinutes * 10) / 10,
          fare,
        });
      }
    } else {
      // Driver is online but not on a ride — broadcast globally (for nearby driver display)
      this.server.emit('driverLocationUpdated', locationPayload);
    }

    return locationPayload;
  }

  @SubscribeMessage('startRide')
  handleStartRide(
    @MessageBody() data: { rideId: string; driverId: string; latitude: number; longitude: number },
    @ConnectedSocket() client: Socket,
  ) {
    // Driver joins the ride room
    client.join(`ride:${data.rideId}`);

    this.activeRides.set(data.rideId, {
      driverId: data.driverId,
      startTime: Date.now(),
      prevLat: data.latitude,
      prevLng: data.longitude,
      totalDistanceKm: 0,
    });

    // Notify ride room that ride is now ONGOING
    this.server.to(`ride:${data.rideId}`).emit('rideStatusChanged', {
      rideId: data.rideId,
      status: 'ONGOING',
    });

    console.log(`[Tracking] Ride started: ${data.rideId}`);
    return { status: 'started', rideId: data.rideId };
  }

  @SubscribeMessage('endRide')
  handleEndRide(@MessageBody() data: { rideId: string }) {
    const ride = this.activeRides.get(data.rideId);
    if (!ride) return { status: 'not_found' };

    const durationSeconds = Math.floor((Date.now() - ride.startTime) / 1000);
    const durationMinutes = durationSeconds / 60;
    const finalFare = this.tariffService.getRealtimeFare(ride.totalDistanceKm, durationMinutes);

    this.activeRides.delete(data.rideId);

    const summary = {
      rideId: data.rideId,
      distanceKm: Math.round(ride.totalDistanceKm * 100) / 100,
      durationMinutes: Math.round(durationMinutes * 10) / 10,
      finalFare,
    };

    this.server.to(`ride:${data.rideId}`).emit('rideEnded', summary);
    this.server.to(`ride:${data.rideId}`).emit('rideStatusChanged', {
      status: 'DONE',
      ...summary,
    });

    console.log(`[Tracking] Ride ended: ${data.rideId}, fare: Rp ${finalFare}`);
    return summary;
  }

  @SubscribeMessage('driverOnline')
  async handleDriverOnline(
    @MessageBody() data: { driverId: string; latitude: number; longitude: number },
    @ConnectedSocket() client: Socket,
  ) {
    console.log(`[handleDriverOnline] called for driverId: ${data.driverId} lat: ${data.latitude} lng: ${data.longitude}`);
    await this.redisService.setDriverLocation(data.driverId, data.latitude, data.longitude);
    this.clientToDriver.set(client.id, data.driverId);
    client.join(`driver:${data.driverId}`);
    this.server.emit('driverStatusChanged', { driverId: data.driverId, status: 'online' });
    this.notifRepo.save(this.notifRepo.create({
      userId: data.driverId,
      title: 'Kamu Online',
      body: 'Kamu sudah online dan siap menerima pesanan.',
      type: 'info',
    }));

    console.log(`[handleDriverOnline] calling _sendPendingRidesToDriver for driverId: ${data.driverId}`);
    this._sendPendingRidesToDriver(data.driverId, data.latitude, data.longitude, client).catch((e) => {
      console.error(`[handleDriverOnline] _sendPendingRidesToDriver error:`, e);
    });

    return { status: 'online', driverId: data.driverId };
  }

  private async _sendPendingRidesToDriver(
    driverId: string,
    driverLat: number,
    driverLng: number,
    client: Socket,
  ) {
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000);
    const pendingRides = await this.rideRepo.find({
      where: {
        status: RideStatus.SEARCHING,
        createdAt: MoreThan(tenMinutesAgo),
      },
      order: { createdAt: 'DESC' },
    });

    console.log(`[PENDING RIDES] found: ${pendingRides.length} rides with SEARCHING status (last 10 min)`);

    const nearby = pendingRides.filter(
      (r) => this.trackingService.haversine(driverLat, driverLng, r.originLat, r.originLng) <= 5,
    );

    console.log(`[PENDING RIDES] nearby (<=50km): ${nearby.length} rides`);

    if (nearby.length === 0) return;

    const passengerIds = [...new Set(nearby.map((r) => r.passengerId))];
    const passengers = await this.userRepo.findBy({ id: In(passengerIds) });
    const passengerMap = new Map(passengers.map((p) => [p.id, p]));

    for (const ride of nearby) {
      const passenger = passengerMap.get(ride.passengerId);
      const distKm = Math.round(
        this.trackingService.haversine(ride.originLat, ride.originLng, ride.destinationLat, ride.destinationLng) * 10,
      ) / 10;

      client.emit('newRideRequest', {
        rideId:             ride.id,
        originLat:          Number(ride.originLat),
        originLng:          Number(ride.originLng),
        destinationLat:     Number(ride.destinationLat),
        destinationLng:     Number(ride.destinationLng),
        originAddress:      ride.originAddress ?? '',
        destinationAddress: ride.destinationAddress ?? '',
        estimatedFare:      this.tariffService.calculate(distKm),
        distanceKm:         distKm,
        passengerName:      passenger?.name || passenger?.phone || 'Penumpang',
        passengerRating:    4.8,
        type:               'NEW_RIDE_REQUEST',
      });

      console.log(`[Tracking] Sent pending ride ${ride.id} to driver ${driverId} who just came online`);
    }
  }

  // Passenger mengirim posisi GPS mereka selama trip
  @SubscribeMessage('updatePassengerLocation')
  async handleUpdatePassengerLocation(
    @MessageBody() data: { passengerId: string; rideId: string; latitude: number; longitude: number },
    @ConnectedSocket() _client: Socket,
  ) {
    // Simpan ke Redis agar driver bisa dapat posisi terbaru saat reconnect (TTL 60 detik)
    await this.redisService.setPassengerLocation(data.rideId, data.latitude, data.longitude);

    // Broadcast ke ride room — driver menerima ini untuk update marker passenger
    this.server.to(`ride:${data.rideId}`).emit('passengerLocationUpdated', {
      rideId: data.rideId,
      latitude: data.latitude,
      longitude: data.longitude,
    });
  }

  @SubscribeMessage('driverOffline')
  async handleDriverOffline(@MessageBody() data: { driverId: string }) {
    await this.redisService.deleteDriverLocation(data.driverId);
    this.server.emit('driverStatusChanged', { driverId: data.driverId, status: 'offline' });
    return { status: 'offline', driverId: data.driverId };
  }

  // Called by BookingService when ride is created — broadcasts only to nearby drivers (≤5 km)
  broadcastNewRide(
    payload: {
      rideId: string;
      originLat: number;
      originLng: number;
      destinationLat: number;
      destinationLng: number;
      originAddress?: string;
      destinationAddress?: string;
      estimatedFare: number;
      distanceKm: number;
      passengerName?: string;
      passengerRating?: number;
    },
    nearbyDriverIds: string[],
  ) {
    if (nearbyDriverIds.length === 0) {
      // No nearby drivers found — do not broadcast globally to avoid cross-province matches
      console.log(`[Tracking] No nearby drivers for ride ${payload.rideId}, skipping broadcast`);
      return;
    }
    for (const driverId of nearbyDriverIds) {
      this.server.to(`driver:${driverId}`).emit('newRideRequest', payload);
    }
    console.log(`[Tracking] broadcastNewRide → ${nearbyDriverIds.length} nearby driver(s) for ride ${payload.rideId}`);
  }

  // Called by BookingService when driver accepts — scoped to ride room
  notifyRideAccepted(payload: {
    rideId: string;
    driverId: string;
    driverName?: string;
    driverPlate?: string;
    driverRating?: number;
    driverPhone?: string;
  }) {
    // Emit to ride room (passenger already joined) + global for driver app
    this.server.to(`ride:${payload.rideId}`).emit('rideAccepted', payload);
    // Also emit globally so driver app knows the accept was confirmed
    this.server.emit('rideAccepted', payload);
  }

  // Called by BookingService on status transitions (PICKUP, ONGOING, DONE)
  notifyRideStatusChanged(rideId: string, status: string, extra?: Record<string, unknown>) {
    this.server.to(`ride:${rideId}`).emit('rideStatusChanged', {
      rideId,
      status,
      ...extra,
    });
  }

  notifyRideCancelled(rideId: string) {
    this.server.to(`ride:${rideId}`).emit('rideCancelled', { rideId });
  }

  // Passenger requests cancellation — driver must approve/reject
  @SubscribeMessage('passengerCancelRequest')
  async handlePassengerCancelRequest(
    @MessageBody() data: { rideId: string },
    @ConnectedSocket() _client: Socket,
  ) {
    this.server.to(`ride:${data.rideId}`).emit('cancelRequest', { rideId: data.rideId });
    // Also emit to driver's personal room in case driver socket reconnected and left ride room
    try {
      const ride = await this.rideRepo.findOne({ where: { id: data.rideId } });
      if (ride?.driverId) {
        this.server.to(`driver:${ride.driverId}`).emit('cancelRequest', { rideId: data.rideId });
      }
    } catch (_) {}
    return { status: 'ok' };
  }

  // Driver approves passenger cancellation
  @SubscribeMessage('driverCancelApproved')
  handleDriverCancelApproved(
    @MessageBody() data: { rideId: string },
    @ConnectedSocket() _client: Socket,
  ) {
    this.server.to(`ride:${data.rideId}`).emit('cancelApproved', { rideId: data.rideId });
    return { status: 'ok' };
  }

  // Driver rejects passenger cancellation
  @SubscribeMessage('driverCancelRejected')
  handleDriverCancelRejected(
    @MessageBody() data: { rideId: string },
    @ConnectedSocket() _client: Socket,
  ) {
    this.server.to(`ride:${data.rideId}`).emit('cancelRejected', { rideId: data.rideId });
    return { status: 'ok' };
  }
}
