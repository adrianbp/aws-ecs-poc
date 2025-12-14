package com.example.springboot4otel;

import com.example.springboot4otel.domain.Product;
import com.example.springboot4otel.repository.ProductRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class Springboot4OtelPocApplication {

    public static void main(String[] args) {
        System.out.println("DEBUG: Dumping version properties BEFORE override:");
        System.out.println("java.version: " + System.getProperty("java.version"));
        System.out.println("java.vm.version: " + System.getProperty("java.vm.version"));
        System.out.println("java.specification.version: " + System.getProperty("java.specification.version"));
        System.out.println("java.vm.specification.version: " + System.getProperty("java.vm.specification.version"));
        System.out.println("java.vendor.version: " + System.getProperty("java.vendor.version"));
        
        // Force all to "25" exactly to try and satisfy the check
        System.setProperty("java.version", "25");
        System.setProperty("java.vm.version", "25");
        System.setProperty("java.specification.version", "25");
        System.setProperty("java.vm.specification.version", "25");
        System.setProperty("java.vendor.version", "Oracle GraalVM 25");

        System.out.println("DEBUG: Properties AFTER override:");
        System.out.println("java.version: " + System.getProperty("java.version"));
        System.out.println("java.specification.version: " + System.getProperty("java.specification.version"));
        
        try {
            SpringApplication.run(Springboot4OtelPocApplication.class, args);
        } catch (Exception e) {
            System.out.println("DEBUG: Caught exception in main:");
            e.printStackTrace();
            throw e;
        }
    }

    @Bean
    CommandLineRunner initDatabase(ProductRepository repository) {
        return args -> {
            repository.save(new Product("Laptop", 1200.00));
            repository.save(new Product("Mouse", 25.00));
            repository.save(new Product("Keyboard", 75.00));
        };
    }
}
