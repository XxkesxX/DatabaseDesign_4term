package ru.marketplace.workload;

public record EventRequest(String eventType, Long sellerOrderId, Long userId) {
}
