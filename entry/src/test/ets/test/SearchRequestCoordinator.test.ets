import { describe, it, expect } from '@ohos/hypium';
import { SearchRequestCoordinator } from '../../../main/ets/common/SearchRequestCoordinator';

export default function searchRequestCoordinatorTest() {
  describe('SearchRequestCoordinator', () => {
    it('清空查询会作废搜索、刷新和建议请求', 0, () => {
      const coordinator = new SearchRequestCoordinator();
      const searchRequestId = coordinator.beginSearch();
      const suggestionRequestId = coordinator.beginSuggestion();
      const filterRequestId = coordinator.beginFilterOptions();

      coordinator.invalidateQueryRequests();

      expect(coordinator.isCurrentSearch(searchRequestId)).assertFalse();
      expect(coordinator.isCurrentSuggestion(suggestionRequestId)).assertFalse();
      expect(coordinator.isCurrentFilterOptions(filterRequestId)).assertTrue();

      const refreshCoordinator = new SearchRequestCoordinator();
      const refreshRequestId = refreshCoordinator.beginRefresh();
      refreshCoordinator.invalidateQueryRequests();

      expect(refreshCoordinator.isCurrentRefresh(refreshRequestId)).assertFalse();
    });

    it('新搜索和刷新会互相作废但使用独立序列', 0, () => {
      const coordinator = new SearchRequestCoordinator();
      const firstRefreshId = coordinator.beginRefresh();
      const searchRequestId = coordinator.beginSearch();

      expect(coordinator.isCurrentRefresh(firstRefreshId)).assertFalse();
      expect(coordinator.isCurrentSearch(searchRequestId)).assertTrue();

      const secondRefreshId = coordinator.beginRefresh();

      expect(coordinator.isCurrentSearch(searchRequestId)).assertFalse();
      expect(coordinator.isCurrentRefresh(secondRefreshId)).assertTrue();
    });

    it('建议请求不会作废搜索和筛选请求', 0, () => {
      const coordinator = new SearchRequestCoordinator();
      const searchRequestId = coordinator.beginSearch();
      const filterRequestId = coordinator.beginFilterOptions();
      const firstSuggestionId = coordinator.beginSuggestion();
      const secondSuggestionId = coordinator.beginSuggestion();

      expect(coordinator.isCurrentSuggestion(firstSuggestionId)).assertFalse();
      expect(coordinator.isCurrentSuggestion(secondSuggestionId)).assertTrue();
      expect(coordinator.isCurrentSearch(searchRequestId)).assertTrue();
      expect(coordinator.isCurrentFilterOptions(filterRequestId)).assertTrue();
    });

    it('筛选条件请求只作废上一次筛选条件请求', 0, () => {
      const coordinator = new SearchRequestCoordinator();
      const searchRequestId = coordinator.beginSearch();
      const suggestionRequestId = coordinator.beginSuggestion();
      const firstFilterRequestId = coordinator.beginFilterOptions();
      const secondFilterRequestId = coordinator.beginFilterOptions();

      expect(coordinator.isCurrentFilterOptions(firstFilterRequestId)).assertFalse();
      expect(coordinator.isCurrentFilterOptions(secondFilterRequestId)).assertTrue();
      expect(coordinator.isCurrentSearch(searchRequestId)).assertTrue();
      expect(coordinator.isCurrentSuggestion(suggestionRequestId)).assertTrue();
    });
  });
}
