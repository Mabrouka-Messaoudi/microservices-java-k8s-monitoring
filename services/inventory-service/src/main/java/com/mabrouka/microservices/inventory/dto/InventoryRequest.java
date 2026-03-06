package com.mabrouka.microservices.inventory.dto;

public record InventoryRequest(
        String skuCode,
        Integer quantity
) {}