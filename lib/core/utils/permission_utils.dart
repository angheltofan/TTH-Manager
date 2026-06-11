String roleName(String role) {
  return switch (role) {
    'admin' => 'Administrator',
    'trainer' => 'Trainer',
    'parent' => 'Părinte',
    _ => role,
  };
}

bool isAdmin(String? role) => role == 'admin';

bool isTrainer(String? role) => role == 'trainer';

bool isParent(String? role) => role == 'parent';
