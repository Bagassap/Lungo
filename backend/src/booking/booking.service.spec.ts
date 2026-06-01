import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken, getDataSourceToken } from '@nestjs/typeorm';
import { BookingService } from './booking.service';
import { Ride } from './entities/ride.entity';
import { User } from '../users/entities/user.entity';
import { Driver } from '../drivers/entities/driver.entity';
import { UserNotification } from '../users/entities/user_notification.entity';
import { TrackingService } from '../tracking/tracking.service';
import { TrackingGateway } from '../tracking/tracking.gateway';
import { FcmService } from './fcm.service';
import { TariffService } from '../tariff/tariff.service';

const mockRepo = () => ({
  find: jest.fn(),
  findOne: jest.fn(),
  save: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  count: jest.fn(),
  createQueryBuilder: jest.fn(() => ({
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    execute: jest.fn().mockResolvedValue({}),
  })),
});

describe('BookingService', () => {
  let service: BookingService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        BookingService,
        { provide: getRepositoryToken(Ride),             useFactory: mockRepo },
        { provide: getRepositoryToken(User),             useFactory: mockRepo },
        { provide: getRepositoryToken(Driver),           useFactory: mockRepo },
        { provide: getRepositoryToken(UserNotification), useFactory: mockRepo },
        {
          provide: getDataSourceToken(),
          useValue: { transaction: jest.fn() },
        },
        { provide: TrackingService,  useValue: { getNearbyDrivers: jest.fn().mockResolvedValue([]) } },
        { provide: TrackingGateway,  useValue: { broadcastNewRide: jest.fn(), notifyRideAccepted: jest.fn(), notifyRideStatusChanged: jest.fn() } },
        { provide: FcmService,       useValue: { notifyNearbyDrivers: jest.fn() } },
        { provide: TariffService,    useValue: { calculate: jest.fn().mockReturnValue(14000) } },
      ],
    }).compile();

    service = module.get<BookingService>(BookingService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
