package ru.marketplace.workload;

public record InventoryRequest(Long skuId, Integer delta) {
}
