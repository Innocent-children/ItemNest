import localUnitTest from './LocalUnit.test';
import appEventBusTest from './ets/test/AppEventBus.test';
import dataFailureMappingTest from './ets/test/DataFailureMapping.test';
import expiryServiceTest from './ets/test/ExpiryService.test';
import itemCreateServiceTest from './ets/test/ItemCreateService.test';
import itemMaintenanceServiceTest from './ets/test/ItemMaintenanceService.test';
import itemSchemaTest from './ets/test/ItemSchema.test';
import itemSearchAndSummaryTest from './ets/test/ItemSearchAndSummary.test';
import itemValidatorTest from './ets/test/ItemValidator.test';
import refreshContractTest from './ets/test/RefreshContract.test';
import routeContractTest from './ets/test/RouteContract.test';

export default function testsuite() {
  localUnitTest();
  appEventBusTest();
  dataFailureMappingTest();
  itemValidatorTest();
  itemSchemaTest();
  itemCreateServiceTest();
  itemMaintenanceServiceTest();
  itemSearchAndSummaryTest();
  expiryServiceTest();
  refreshContractTest();
  routeContractTest();
}
