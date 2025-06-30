package handlers_test

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/mock"

	"../handlers"
	"../mocks"
	"../models"
)

// MockUserService para testes
type MockUserService struct {
	mock.Mock
}

func (m *MockUserService) Login(email, password string) (*models.Token, error) {
	args := m.Called(email, password)
	return args.Get(0).(*models.Token), args.Error(1)
}

func (m *MockUserService) Register(user *models.User) error {
	args := m.Called(user)
	return args.Error(0)
}

func (m *MockUserService) ValidateToken(token string) (*models.User, error) {
	args := m.Called(token)
	return args.Get(0).(*models.User), args.Error(1)
}

func TestAuthHandler_Login(t *testing.T) {
	tests := []struct {
		name           string
		requestBody    interface{}
		setupMock      func(*MockUserService)
		expectedStatus int
		expectedBody   string
	}{
		{
			name: "successful_login",
			requestBody: map[string]string{
				"email":    "test@example.com",
				"password": "password123",
			},
			setupMock: func(m *MockUserService) {
				token := &models.Token{
					AccessToken:  "valid_token",
					RefreshToken: "refresh_token",
					ExpiresAt:    time.Now().Add(time.Hour),
				}
				m.On("Login", "test@example.com", "password123").Return(token, nil)
			},
			expectedStatus: http.StatusOK,
			expectedBody:   `{"access_token":"valid_token","refresh_token":"refresh_token"}`,
		},
		{
			name: "invalid_credentials",
			requestBody: map[string]string{
				"email":    "test@example.com",
				"password": "wrongpassword",
			},
			setupMock: func(m *MockUserService) {
				m.On("Login", "test@example.com", "wrongpassword").Return((*models.Token)(nil), errors.New("invalid credentials"))
			},
			expectedStatus: http.StatusUnauthorized,
			expectedBody:   `{"error":"invalid credentials"}`,
		},
		{
			name: "missing_email",
			requestBody: map[string]string{
				"password": "password123",
			},
			setupMock:      func(m *MockUserService) {},
			expectedStatus: http.StatusBadRequest,
			expectedBody:   `{"error":"email is required"}`,
		},
		{
			name: "missing_password",
			requestBody: map[string]string{
				"email": "test@example.com",
			},
			setupMock:      func(m *MockUserService) {},
			expectedStatus: http.StatusBadRequest,
			expectedBody:   `{"error":"password is required"}`,
		},
		{
			name:           "invalid_json",
			requestBody:    "invalid json",
			setupMock:      func(m *MockUserService) {},
			expectedStatus: http.StatusBadRequest,
			expectedBody:   `{"error":"invalid JSON"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			mockService := &MockUserService{}
			tt.setupMock(mockService)

			handler := handlers.NewAuthHandler(mockService)

			var reqBody []byte
			var err error
			if str, ok := tt.requestBody.(string); ok {
				reqBody = []byte(str)
			} else {
				reqBody, err = json.Marshal(tt.requestBody)
				assert.NoError(t, err)
			}

			req := httptest.NewRequest(http.MethodPost, "/login", bytes.NewReader(reqBody))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			// Act
			handler.Login(w, req)

			// Assert
			assert.Equal(t, tt.expectedStatus, w.Code)
			
			if tt.expectedBody != "" {
				assert.JSONEq(t, tt.expectedBody, w.Body.String())
			}

			mockService.AssertExpectations(t)
		})
	}
}

func TestAuthHandler_Register(t *testing.T) {
	tests := []struct {
		name           string
		requestBody    interface{}
		setupMock      func(*MockUserService)
		expectedStatus int
		expectedBody   string
	}{
		{
			name: "successful_registration",
			requestBody: map[string]string{
				"email":    "newuser@example.com",
				"password": "password123",
				"name":     "Test User",
			},
			setupMock: func(m *MockUserService) {
				m.On("Register", mock.AnythingOfType("*models.User")).Return(nil)
			},
			expectedStatus: http.StatusCreated,
			expectedBody:   `{"message":"user created successfully"}`,
		},
		{
			name: "email_already_exists",
			requestBody: map[string]string{
				"email":    "existing@example.com",
				"password": "password123",
				"name":     "Test User",
			},
			setupMock: func(m *MockUserService) {
				m.On("Register", mock.AnythingOfType("*models.User")).Return(errors.New("email already exists"))
			},
			expectedStatus: http.StatusConflict,
			expectedBody:   `{"error":"email already exists"}`,
		},
		{
			name: "invalid_email_format",
			requestBody: map[string]string{
				"email":    "invalid-email",
				"password": "password123",
				"name":     "Test User",
			},
			setupMock:      func(m *MockUserService) {},
			expectedStatus: http.StatusBadRequest,
			expectedBody:   `{"error":"invalid email format"}`,
		},
		{
			name: "password_too_short",
			requestBody: map[string]string{
				"email":    "test@example.com",
				"password": "123",
				"name":     "Test User",
			},
			setupMock:      func(m *MockUserService) {},
			expectedStatus: http.StatusBadRequest,
			expectedBody:   `{"error":"password must be at least 6 characters"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			mockService := &MockUserService{}
			tt.setupMock(mockService)

			handler := handlers.NewAuthHandler(mockService)

			reqBody, err := json.Marshal(tt.requestBody)
			assert.NoError(t, err)

			req := httptest.NewRequest(http.MethodPost, "/register", bytes.NewReader(reqBody))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()

			// Act
			handler.Register(w, req)

			// Assert
			assert.Equal(t, tt.expectedStatus, w.Code)
			assert.JSONEq(t, tt.expectedBody, w.Body.String())

			mockService.AssertExpectations(t)
		})
	}
}

func TestAuthHandler_ValidateToken(t *testing.T) {
	tests := []struct {
		name           string
		authHeader     string
		setupMock      func(*MockUserService)
		expectedStatus int
		expectedBody   string
	}{
		{
			name:       "valid_token",
			authHeader: "Bearer valid_jwt_token",
			setupMock: func(m *MockUserService) {
				user := &models.User{
					ID:    1,
					Email: "test@example.com",
					Name:  "Test User",
				}
				m.On("ValidateToken", "valid_jwt_token").Return(user, nil)
			},
			expectedStatus: http.StatusOK,
			expectedBody:   `{"id":1,"email":"test@example.com","name":"Test User"}`,
		},
		{
			name:       "invalid_token",
			authHeader: "Bearer invalid_token",
			setupMock: func(m *MockUserService) {
				m.On("ValidateToken", "invalid_token").Return((*models.User)(nil), errors.New("invalid token"))
			},
			expectedStatus: http.StatusUnauthorized,
			expectedBody:   `{"error":"invalid token"}`,
		},
		{
			name:           "missing_authorization_header",
			authHeader:     "",
			setupMock:      func(m *MockUserService) {},
			expectedStatus: http.StatusUnauthorized,
			expectedBody:   `{"error":"authorization header required"}`,
		},
		{
			name:           "invalid_authorization_format",
			authHeader:     "InvalidFormat token",
			setupMock:      func(m *MockUserService) {},
			expectedStatus: http.StatusUnauthorized,
			expectedBody:   `{"error":"invalid authorization format"}`,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Arrange
			mockService := &MockUserService{}
			tt.setupMock(mockService)

			handler := handlers.NewAuthHandler(mockService)

			req := httptest.NewRequest(http.MethodGet, "/validate", nil)
			if tt.authHeader != "" {
				req.Header.Set("Authorization", tt.authHeader)
			}
			w := httptest.NewRecorder()

			// Act
			handler.ValidateToken(w, req)

			// Assert
			assert.Equal(t, tt.expectedStatus, w.Code)
			assert.JSONEq(t, tt.expectedBody, w.Body.String())

			mockService.AssertExpectations(t)
		})
	}
}

// Benchmarks
func BenchmarkAuthHandler_Login(b *testing.B) {
	mockService := &MockUserService{}
	token := &models.Token{
		AccessToken:  "benchmark_token",
		RefreshToken: "refresh_token",
		ExpiresAt:    time.Now().Add(time.Hour),
	}
	mockService.On("Login", "test@example.com", "password123").Return(token, nil)

	handler := handlers.NewAuthHandler(mockService)

	requestBody := map[string]string{
		"email":    "test@example.com",
		"password": "password123",
	}
	reqBody, _ := json.Marshal(requestBody)

	b.ResetTimer()
	b.RunParallel(func(pb *testing.PB) {
		for pb.Next() {
			req := httptest.NewRequest(http.MethodPost, "/login", bytes.NewReader(reqBody))
			req.Header.Set("Content-Type", "application/json")
			w := httptest.NewRecorder()
			
			handler.Login(w, req)
		}
	})
}
