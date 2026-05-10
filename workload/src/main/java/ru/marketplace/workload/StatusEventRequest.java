package ru.marketplace.workload;

public record StatusEventRequest(Long sellerOrderId, String statusCode) {
}
