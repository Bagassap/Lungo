import { Test, TestingModule } from '@nestjs/testing';
import { TrackingService } from './tracking.service';
import { RedisService } from './redis.service';

describe('TrackingService', () => {
  let service: TrackingService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TrackingService,
        {
          provide: RedisService,
          useValue: {
            getAllDriverKeys: jest.fn().mockResolvedValue([]),
            getDriverLocation: jest.fn().mockResolvedValue(null),
            setDriverLocation: jest.fn().mockResolvedValue(undefined),
            deleteDriverLocation: jest.fn().mockResolvedValue(undefined),
          },
        },
      ],
    }).compile();

    service = module.get<TrackingService>(TrackingService);
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
