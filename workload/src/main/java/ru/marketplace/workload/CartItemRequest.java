package ru.marketplace.workload;

public record CartItemRequest(Long userId, Long skuId, Integer qty) {
}
