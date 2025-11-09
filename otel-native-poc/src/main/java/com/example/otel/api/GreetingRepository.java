package com.example.otel.api;

import io.opentelemetry.instrumentation.annotations.WithSpan;
import java.util.List;
import java.util.Optional;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.RowMapper;
import org.springframework.stereotype.Repository;

@Repository
public class GreetingRepository {

    private final JdbcTemplate jdbcTemplate;
    private final RowMapper<Greeting> mapper = (rs, rowNum) ->
        new Greeting(rs.getLong("id"), rs.getString("message"), rs.getString("language"));

    public GreetingRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    @WithSpan("greeting.findAll")
    public List<Greeting> findAll() {
        return jdbcTemplate.query("SELECT id, message, language FROM greetings ORDER BY id", mapper);
    }

    @WithSpan("greeting.findById")
    public Optional<Greeting> findById(Long id) {
        List<Greeting> result = jdbcTemplate.query("SELECT id, message, language FROM greetings WHERE id = ?", mapper, id);
        return result.stream().findFirst();
    }
}
