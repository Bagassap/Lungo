import { Test, TestingModule } from '@nestjs/testing';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { AuthService } from '../auth/auth.service';

describe('UsersController', () => {
  let controller: UsersController;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        {
          provide: UsersService,
          useValue: {
            findById: jest.fn(),
            updateProfile: jest.fn(),
            getStats: jest.fn(),
            getActivityStats: jest.fn(),
            getAddresses: jest.fn(),
            addAddress: jest.fn(),
            deleteAddress: jest.fn(),
            getNotifications: jest.fn(),
            markNotificationsRead: jest.fn(),
            createNotification: jest.fn(),
            markNotificationRead: jest.fn(),
            deleteNotification: jest.fn(),
            getEnrichedHistory: jest.fn(),
            getLastDestinations: jest.fn(),
            getLocationSuggestions: jest.fn(),
          },
        },
        {
          provide: AuthService,
          useValue: {
            selectRole: jest.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get<UsersController>(UsersController);
  });

  it('should be defined', () => {
    expect(controller).toBeDefined();
  });
});
