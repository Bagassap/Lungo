import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { TariffService } from './tariff.service';
import { TariffConfig } from './entities/tariff_config.entity';
import { TariffHistory } from './entities/tariff_history.entity';

const mockRepo = () => ({
  findOne: jest.fn().mockResolvedValue({
    id: 1, basePrice: 14000, pricePerKm: 2100, pricePerMinute: 500, minimumFare: 14000,
  }),
  save: jest.fn(),
  create: jest.fn(),
  find: jest.fn().mockResolvedValue([]),
});

describe('TariffService', () => {
  let service: TariffService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TariffService,
        { provide: getRepositoryToken(TariffConfig),  useFactory: mockRepo },
        { provide: getRepositoryToken(TariffHistory), useFactory: mockRepo },
      ],
    }).compile();

    service = module.get<TariffService>(TariffService);
    await service.onModuleInit();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });

  it('calculate() should return at least base price', () => {
    expect(service.calculate(1)).toBe(14000);
    expect(service.calculate(10)).toBe(21000);
  });
});
