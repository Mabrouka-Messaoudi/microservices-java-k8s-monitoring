package com.mabrouka.microservices.product.repository;

import com.mabrouka.microservices.product.model.Product;
import org.springframework.data.mongodb.repository.MongoRepository;

public interface ProductRepository extends MongoRepository<Product, String> {
}
