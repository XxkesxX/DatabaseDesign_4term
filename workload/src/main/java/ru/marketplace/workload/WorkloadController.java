package ru.marketplace.workload;

import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api")
public class WorkloadController {
    private final WorkloadService workloadService;

    public WorkloadController(WorkloadService workloadService) {
        this.workloadService = workloadService;
    }

    @GetMapping("/meta/counts")
    public Map<String, Object> counts() {
        return workloadService.counts();
    }

    @GetMapping("/oltp/orders/{orderId}")
    public Map<String, Object> order(@PathVariable long orderId) {
        return workloadService.order(orderId);
    }

    @PostMapping("/oltp/cart-items")
    public Map<String, Object> cartItem(@RequestBody(required = false) CartItemRequest request) {
        CartItemRequest body = request == null ? new CartItemRequest(1L, 1L, 1) : request;
        return workloadService.upsertCartItem(body.userId(), body.skuId(), body.qty());
    }

    @PatchMapping("/oltp/inventory")
    public Map<String, Object> inventory(@RequestBody(required = false) InventoryRequest request) {
        InventoryRequest body = request == null ? new InventoryRequest(1L, -1) : request;
        return workloadService.updateInventory(body.skuId(), body.delta());
    }

    @GetMapping("/olap/seller-revenue")
    public Map<String, Object> sellerRevenue(
            @RequestParam(defaultValue = "365") int fromDaysAgo,
            @RequestParam(defaultValue = "0") int toDaysAgo,
            @RequestParam(defaultValue = "50") int limit
    ) {
        return workloadService.sellerRevenue(fromDaysAgo, toDaysAgo, limit);
    }

    @GetMapping("/olap/catalog-health")
    public Map<String, Object> catalogHealth(
            @RequestParam(defaultValue = "50") int minPrice,
            @RequestParam(defaultValue = "1000") int maxPrice,
            @RequestParam(defaultValue = "100") int minQty,
            @RequestParam(defaultValue = "50") int limit
    ) {
        return workloadService.catalogHealth(minPrice, maxPrice, minQty, limit);
    }

    @PostMapping("/log/status")
    public Map<String, Object> status(@RequestBody(required = false) StatusEventRequest request) {
        StatusEventRequest body = request == null ? new StatusEventRequest(1L, "paid") : request;
        return workloadService.insertStatus(body.sellerOrderId(), body.statusCode());
    }

    @PostMapping("/log/events")
    public Map<String, Object> event(@RequestBody(required = false) EventRequest request) {
        EventRequest body = request == null ? new EventRequest("status_changed", 1L, 1L) : request;
        return workloadService.insertEvent(body.eventType(), body.sellerOrderId(), body.userId());
    }

    @PostMapping("/admin/revenue-view/refresh")
    public ResponseEntity<Map<String, Object>> refreshRevenueView() {
        return ResponseEntity.ok(workloadService.refreshRevenueView());
    }
}
