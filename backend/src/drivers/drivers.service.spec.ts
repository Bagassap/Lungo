import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { DriversService } from './drivers.service';
import { Driver } from './entities/driver.entity';
import { User } from '../users/entities/user.entity';
import { Ride } from '../booking/entities/ride.entity';
import { RedisService } from '../tracking/redis.service';

const mockRepo = () => ({
  find: jest.fn(),
  findOne: jest.fn(),
  save: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  count: jest.fn(),
  createQueryBuilder: jest.fn(() => ({
    select: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    take: jest.fn().mockReturnThis(),
    getRawOne: jest.fn().mockResolvedValue(null),
    getMany: jest.fn().mockResolvedValue([]),
  })),
});

describe('DriversService', () => {
  let service: DriversService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        DriversService,
        { provide: getRepositoryToken(Driver), useFactory: mockRepo },
        { provide: getRepositoryToken(User),   useFactory: mockRepo },
        { provide: getRepositoryToken(Ride),   useFactory: mockRepo },
        {
          provide: RedisService,
          useValue: {
            setDriverLocation: jest.fn(),
            deleteDriverLocation: jest.fn(),
            getDriverLocation: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get<DriversService>(DriversService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
