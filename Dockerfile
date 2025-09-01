# Multi-stage build for Spring PetClinic
FROM eclipse-temurin:17-jdk AS builder

# Install necessary packages
RUN apk add --no-cache curl

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy Maven wrapper and POM files
COPY mvnw ./
COPY .mvn .mvn
COPY pom.xml ./

# Download dependencies
RUN ./mvnw dependency:go-offline -B

# Copy source code
COPY src ./src

# Build the application
RUN ./mvnw clean package -DskipTests && \
    ./mvnw dependency:copy-dependencies -DincludeScope=runtime

# Runtime stage
FROM eclipse-temurin:17-jre

# Install security updates and necessary packages
RUN apk add --no-cache --update \
    ca-certificates \
    tzdata \
    && rm -rf /var/cache/apk/*

# Create non-root user
RUN addgroup -g 1001 -S appgroup && \
    adduser -u 1001 -S appuser -G appgroup

# Set working directory
WORKDIR /app

# Copy built application from builder stage
COPY --from=builder --chown=appuser:appgroup /app/target/spring-petclinic-*.jar app.jar
COPY --from=builder --chown=appuser:appgroup /app/target/dependency/ dependency/

# Create necessary directories with proper permissions
RUN mkdir -p /app/logs && \
    chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/actuator/health || exit 1

# JVM options for production
ENV JAVA_OPTS="-Xms512m -Xmx1024m -XX:+UseG1GC -XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"

# Run the application
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
