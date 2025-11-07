package com.example.ecs.api;

import java.util.List;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
class GreetingRepository {
    private final JdbcTemplate jdbcTemplate;

    GreetingRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    List<GreetingRecord> findAll() {
        return jdbcTemplate.query(
            "SELECT id, message FROM greetings ORDER BY id",
            (rs, rowNum) -> new GreetingRecord(rs.getLong("id"), rs.getString("message"))
        );
    }
}
