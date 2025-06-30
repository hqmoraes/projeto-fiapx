package integration_test

import (
	"context"
	"database/sql"
	"fmt"
	"os"
	"testing"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/suite"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/modules/postgres"
	"github.com/testcontainers/testcontainers-go/modules/redis"

	"../internal/repositories"
	"../internal/services"
	"../models"
)

// IntegrationTestSuite define uma suite de testes de integração
type IntegrationTestSuite struct {
	suite.Suite
	pgContainer    *postgres.PostgresContainer
	redisContainer *redis.RedisContainer
	db             *sql.DB
	redisClient    *redis.Client
	userRepo       repositories.UserRepository
	authService    services.AuthService
}

// SetupSuite é executado uma vez antes de todos os testes
func (suite *IntegrationTestSuite) SetupSuite() {
	ctx := context.Background()

	// Setup PostgreSQL container
	pgContainer, err := postgres.RunContainer(ctx,
		testcontainers.WithImage("postgres:13-alpine"),
		postgres.WithDatabase("testdb"),
		postgres.WithUsername("testuser"),
		postgres.WithPassword("testpass"),
		testcontainers.WithWaitStrategy(wait.ForLog("database system is ready to accept connections").
			WithOccurrence(2).WithStartupTimeout(5*time.Second)))
	suite.Require().NoError(err)
	suite.pgContainer = pgContainer

	// Setup Redis container
	redisContainer, err := redis.RunContainer(ctx,
		testcontainers.WithImage("redis:7-alpine"))
	suite.Require().NoError(err)
	suite.redisContainer = redisContainer

	// Connect to PostgreSQL
	connStr, err := pgContainer.ConnectionString(ctx, "sslmode=disable")
	suite.Require().NoError(err)

	suite.db, err = sql.Open("postgres", connStr)
	suite.Require().NoError(err)

	// Connect to Redis
	redisEndpoint, err := redisContainer.Endpoint(ctx, "")
	suite.Require().NoError(err)

	suite.redisClient = redis.NewClient(&redis.Options{
		Addr: redisEndpoint,
	})

	// Run migrations
	suite.runMigrations()

	// Initialize repositories and services
	suite.userRepo = repositories.NewUserRepository(suite.db)
	suite.authService = services.NewAuthService(suite.userRepo, suite.redisClient, "test-secret")
}

// TearDownSuite é executado uma vez após todos os testes
func (suite *IntegrationTestSuite) TearDownSuite() {
	ctx := context.Background()
	
	if suite.db != nil {
		suite.db.Close()
	}
	
	if suite.redisClient != nil {
		suite.redisClient.Close()
	}
	
	if suite.pgContainer != nil {
		suite.pgContainer.Terminate(ctx)
	}
	
	if suite.redisContainer != nil {
		suite.redisContainer.Terminate(ctx)
	}
}

// SetupTest é executado antes de cada teste
func (suite *IntegrationTestSuite) SetupTest() {
	// Limpar dados entre testes
	suite.clearData()
}

func (suite *IntegrationTestSuite) runMigrations() {
	migrations := []string{
		`CREATE TABLE IF NOT EXISTS users (
			id SERIAL PRIMARY KEY,
			email VARCHAR(255) UNIQUE NOT NULL,
			password_hash VARCHAR(255) NOT NULL,
			name VARCHAR(255) NOT NULL,
			created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
			updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
		)`,
		`CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)`,
	}

	for _, migration := range migrations {
		_, err := suite.db.Exec(migration)
		suite.Require().NoError(err)
	}
}

func (suite *IntegrationTestSuite) clearData() {
	// Limpar tabelas
	_, err := suite.db.Exec("TRUNCATE users RESTART IDENTITY CASCADE")
	suite.Require().NoError(err)

	// Limpar Redis
	err = suite.redisClient.FlushDB(context.Background()).Err()
	suite.Require().NoError(err)
}

func (suite *IntegrationTestSuite) TestUserRegistrationAndLogin() {
	// Test user registration
	user := &models.User{
		Email:    "integration@test.com",
		Password: "password123",
		Name:     "Integration Test User",
	}

	err := suite.authService.Register(user)
	suite.Assert().NoError(err)
	suite.Assert().NotZero(user.ID)

	// Verify user exists in database
	var count int
	err = suite.db.QueryRow("SELECT COUNT(*) FROM users WHERE email = $1", user.Email).Scan(&count)
	suite.Assert().NoError(err)
	suite.Assert().Equal(1, count)

	// Test login
	token, err := suite.authService.Login(user.Email, "password123")
	suite.Assert().NoError(err)
	suite.Assert().NotNil(token)
	suite.Assert().NotEmpty(token.AccessToken)
	suite.Assert().NotEmpty(token.RefreshToken)

	// Test login with wrong password
	_, err = suite.authService.Login(user.Email, "wrongpassword")
	suite.Assert().Error(err)
}

func (suite *IntegrationTestSuite) TestTokenValidation() {
	// Create user
	user := &models.User{
		Email:    "token@test.com",
		Password: "password123",
		Name:     "Token Test User",
	}

	err := suite.authService.Register(user)
	suite.Require().NoError(err)

	// Login to get token
	token, err := suite.authService.Login(user.Email, "password123")
	suite.Require().NoError(err)

	// Validate token
	validatedUser, err := suite.authService.ValidateToken(token.AccessToken)
	suite.Assert().NoError(err)
	suite.Assert().Equal(user.Email, validatedUser.Email)
	suite.Assert().Equal(user.Name, validatedUser.Name)

	// Test invalid token
	_, err = suite.authService.ValidateToken("invalid.token.here")
	suite.Assert().Error(err)
}

func (suite *IntegrationTestSuite) TestUserRepository() {
	// Test Create
	user := &models.User{
		Email:        "repo@test.com",
		PasswordHash: "hashed_password",
		Name:         "Repo Test User",
	}

	err := suite.userRepo.Create(user)
	suite.Assert().NoError(err)
	suite.Assert().NotZero(user.ID)

	// Test FindByEmail
	foundUser, err := suite.userRepo.FindByEmail(user.Email)
	suite.Assert().NoError(err)
	suite.Assert().Equal(user.Email, foundUser.Email)
	suite.Assert().Equal(user.Name, foundUser.Name)

	// Test FindByID
	foundUser, err = suite.userRepo.FindByID(user.ID)
	suite.Assert().NoError(err)
	suite.Assert().Equal(user.Email, foundUser.Email)

	// Test Update
	user.Name = "Updated Name"
	err = suite.userRepo.Update(user)
	suite.Assert().NoError(err)

	foundUser, err = suite.userRepo.FindByID(user.ID)
	suite.Assert().NoError(err)
	suite.Assert().Equal("Updated Name", foundUser.Name)

	// Test Delete
	err = suite.userRepo.Delete(user.ID)
	suite.Assert().NoError(err)

	_, err = suite.userRepo.FindByID(user.ID)
	suite.Assert().Error(err)
}

func (suite *IntegrationTestSuite) TestRedisIntegration() {
	ctx := context.Background()

	// Test basic Redis operations
	err := suite.redisClient.Set(ctx, "test:key", "test_value", time.Hour).Err()
	suite.Assert().NoError(err)

	value, err := suite.redisClient.Get(ctx, "test:key").Result()
	suite.Assert().NoError(err)
	suite.Assert().Equal("test_value", value)

	// Test session storage (simulating what auth service would do)
	sessionKey := "session:user123"
	sessionData := map[string]interface{}{
		"user_id": 123,
		"email":   "session@test.com",
		"expires": time.Now().Add(time.Hour).Unix(),
	}

	// Store session
	err = suite.redisClient.HMSet(ctx, sessionKey, sessionData).Err()
	suite.Assert().NoError(err)

	err = suite.redisClient.Expire(ctx, sessionKey, time.Hour).Err()
	suite.Assert().NoError(err)

	// Retrieve session
	result, err := suite.redisClient.HGetAll(ctx, sessionKey).Result()
	suite.Assert().NoError(err)
	suite.Assert().Equal("123", result["user_id"])
	suite.Assert().Equal("session@test.com", result["email"])
}

func (suite *IntegrationTestSuite) TestConcurrentUserCreation() {
	// Test concurrent access to avoid race conditions
	const numGoroutines = 10
	done := make(chan error, numGoroutines)

	for i := 0; i < numGoroutines; i++ {
		go func(index int) {
			user := &models.User{
				Email:    fmt.Sprintf("concurrent%d@test.com", index),
				Password: "password123",
				Name:     fmt.Sprintf("Concurrent User %d", index),
			}

			err := suite.authService.Register(user)
			done <- err
		}(i)
	}

	// Wait for all goroutines to complete
	for i := 0; i < numGoroutines; i++ {
		err := <-done
		suite.Assert().NoError(err)
	}

	// Verify all users were created
	var count int
	err := suite.db.QueryRow("SELECT COUNT(*) FROM users WHERE email LIKE 'concurrent%@test.com'").Scan(&count)
	suite.Assert().NoError(err)
	suite.Assert().Equal(numGoroutines, count)
}

func (suite *IntegrationTestSuite) TestDatabaseConstraints() {
	user1 := &models.User{
		Email:    "duplicate@test.com",
		Password: "password123",
		Name:     "First User",
	}

	user2 := &models.User{
		Email:    "duplicate@test.com", // Same email
		Password: "password456",
		Name:     "Second User",
	}

	// First user should succeed
	err := suite.authService.Register(user1)
	suite.Assert().NoError(err)

	// Second user with same email should fail
	err = suite.authService.Register(user2)
	suite.Assert().Error(err)
	suite.Assert().Contains(err.Error(), "email already exists")
}

// TestMain setup para os testes de integração
func TestMain(m *testing.M) {
	// Verificar se devemos pular testes de integração
	if os.Getenv("SKIP_INTEGRATION_TESTS") == "true" {
		fmt.Println("Skipping integration tests")
		os.Exit(0)
	}

	// Executar testes
	code := m.Run()
	os.Exit(code)
}

// TestIntegrationSuite executa toda a suite de testes
func TestIntegrationSuite(t *testing.T) {
	suite.Run(t, new(IntegrationTestSuite))
}
