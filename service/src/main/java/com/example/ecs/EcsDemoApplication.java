package com.example.ecs;

import com.example.ecs.api.GreetingRecord;
import org.springframework.aot.hint.annotation.RegisterReflectionForBinding;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

@SpringBootApplication
@RegisterReflectionForBinding(GreetingRecord.class)
public class EcsDemoApplication {

    public static void main(String[] args) {
        SpringApplication.run(EcsDemoApplication.class, args);
    }
}
