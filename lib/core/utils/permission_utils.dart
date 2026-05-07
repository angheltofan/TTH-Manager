String roleName(String role) {
  return switch (role) {
    'admin' => 'Administrator',
    'trainer' => 'Trainer',
    _ => role,
  };
}

bool isAdmin(String? role) => role == 'admin';

bool isTrainer(String? role) => role == 'trainer';
