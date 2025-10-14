// Expense Tracker App JavaScript

class ExpenseTracker {
    constructor() {
        this.expenses = JSON.parse(localStorage.getItem('expenses')) || [];
        this.init();
    }

    init() {
        this.bindEvents();
        this.updateSummary();
        this.renderExpenses();
        this.setTodayDate();
    }

    bindEvents() {
        // Form submission
        const form = document.getElementById('expenseForm');
        if (form) {
            form.addEventListener('submit', (e) => this.handleSubmit(e));
        }

        // Navigation
        this.setupNavigation();
        this.setupMobileMenu();
    }

    setupNavigation() {
        // Smooth scrolling for navigation links
        document.querySelectorAll('a[href^="#"]').forEach(anchor => {
            anchor.addEventListener('click', function (e) {
                e.preventDefault();
                const target = document.querySelector(this.getAttribute('href'));
                if (target) {
                    target.scrollIntoView({
                        behavior: 'smooth',
                        block: 'start'
                    });
                }
            });
        });
    }

    setupMobileMenu() {
        const hamburger = document.querySelector('.hamburger');
        const navMenu = document.querySelector('.nav-menu');

        if (hamburger && navMenu) {
            hamburger.addEventListener('click', () => {
                hamburger.classList.toggle('active');
                navMenu.classList.toggle('active');
            });

            // Close menu when clicking on a link
            document.querySelectorAll('.nav-link').forEach(link => {
                link.addEventListener('click', () => {
                    hamburger.classList.remove('active');
                    navMenu.classList.remove('active');
                });
            });
        }
    }

    setTodayDate() {
        const dateInput = document.getElementById('date');
        if (dateInput) {
            const today = new Date().toISOString().split('T')[0];
            dateInput.value = today;
        }
    }

    handleSubmit(e) {
        e.preventDefault();
        
        const formData = new FormData(e.target);
        const expense = {
            id: Date.now(),
            amount: parseFloat(formData.get('amount') || document.getElementById('amount').value),
            description: formData.get('description') || document.getElementById('description').value,
            category: formData.get('category') || document.getElementById('category').value,
            date: formData.get('date') || document.getElementById('date').value
        };

        // Validate expense data
        if (!expense.amount || !expense.description || !expense.category || !expense.date) {
            alert('Please fill in all fields');
            return;
        }

        this.addExpense(expense);
        e.target.reset();
        this.setTodayDate();
    }

    addExpense(expense) {
        this.expenses.unshift(expense);
        this.saveToStorage();
        this.updateSummary();
        this.renderExpenses();
        this.showNotification('Expense added successfully!');
    }

    deleteExpense(id) {
        this.expenses = this.expenses.filter(expense => expense.id !== id);
        this.saveToStorage();
        this.updateSummary();
        this.renderExpenses();
        this.showNotification('Expense deleted successfully!');
    }

    saveToStorage() {
        localStorage.setItem('expenses', JSON.stringify(this.expenses));
    }

    updateSummary() {
        const totalSpent = this.expenses.reduce((sum, expense) => sum + expense.amount, 0);
        const currentMonth = new Date().getMonth();
        const currentYear = new Date().getFullYear();
        
        const monthlySpent = this.expenses
            .filter(expense => {
                const expenseDate = new Date(expense.date);
                return expenseDate.getMonth() === currentMonth && 
                       expenseDate.getFullYear() === currentYear;
            })
            .reduce((sum, expense) => sum + expense.amount, 0);

        const transactionCount = this.expenses.length;

        // Update DOM elements
        const totalSpentEl = document.getElementById('totalSpent');
        const monthlySpentEl = document.getElementById('monthlySpent');
        const transactionCountEl = document.getElementById('transactionCount');

        if (totalSpentEl) totalSpentEl.textContent = `$${totalSpent.toFixed(2)}`;
        if (monthlySpentEl) monthlySpentEl.textContent = `$${monthlySpent.toFixed(2)}`;
        if (transactionCountEl) transactionCountEl.textContent = transactionCount;
    }

    renderExpenses() {
        const expensesList = document.getElementById('expensesList');
        if (!expensesList) return;

        if (this.expenses.length === 0) {
            expensesList.innerHTML = '<p class="no-expenses">No expenses added yet. Start by adding your first expense!</p>';
            return;
        }

        const expensesHTML = this.expenses
            .slice(0, 10) // Show only the latest 10 expenses
            .map(expense => this.createExpenseHTML(expense))
            .join('');

        expensesList.innerHTML = expensesHTML;
    }

    createExpenseHTML(expense) {
        const categoryIcons = {
            food: 'fas fa-utensils',
            transport: 'fas fa-car',
            shopping: 'fas fa-shopping-bag',
            entertainment: 'fas fa-film',
            bills: 'fas fa-file-invoice-dollar',
            healthcare: 'fas fa-heartbeat',
            other: 'fas fa-ellipsis-h'
        };

        const icon = categoryIcons[expense.category] || categoryIcons.other;
        const date = new Date(expense.date).toLocaleDateString();

        return `
            <div class="expense-item" data-id="${expense.id}">
                <div class="expense-details">
                    <div style="display: flex; align-items: center; gap: 10px;">
                        <i class="${icon}" style="color: #667eea;"></i>
                        <div>
                            <h5>${expense.description}</h5>
                            <p>${this.capitalizeFirst(expense.category)} • ${date}</p>
                        </div>
                    </div>
                </div>
                <div style="display: flex; align-items: center; gap: 10px;">
                    <span class="expense-amount">-$${expense.amount.toFixed(2)}</span>
                    <button onclick="expenseTracker.deleteExpense(${expense.id})" 
                            style="background: none; border: none; color: #e74c3c; cursor: pointer; font-size: 1.2rem;"
                            title="Delete expense">
                        <i class="fas fa-trash"></i>
                    </button>
                </div>
            </div>
        `;
    }

    capitalizeFirst(str) {
        return str.charAt(0).toUpperCase() + str.slice(1);
    }

    showNotification(message) {
        // Create notification element
        const notification = document.createElement('div');
        notification.className = 'notification';
        notification.textContent = message;
        notification.style.cssText = `
            position: fixed;
            top: 90px;
            right: 20px;
            background: #27ae60;
            color: white;
            padding: 15px 20px;
            border-radius: 5px;
            box-shadow: 0 4px 12px rgba(0,0,0,0.15);
            z-index: 1001;
            opacity: 0;
            transform: translateX(100%);
            transition: all 0.3s ease;
        `;

        document.body.appendChild(notification);

        // Animate in
        setTimeout(() => {
            notification.style.opacity = '1';
            notification.style.transform = 'translateX(0)';
        }, 100);

        // Remove after 3 seconds
        setTimeout(() => {
            notification.style.opacity = '0';
            notification.style.transform = 'translateX(100%)';
            setTimeout(() => {
                if (notification.parentNode) {
                    notification.parentNode.removeChild(notification);
                }
            }, 300);
        }, 3000);
    }

    // Export data functionality
    exportData() {
        const dataStr = JSON.stringify(this.expenses, null, 2);
        const dataBlob = new Blob([dataStr], {type: 'application/json'});
        const url = URL.createObjectURL(dataBlob);
        const link = document.createElement('a');
        link.href = url;
        link.download = 'mint-track-expenses.json';
        link.click();
        URL.revokeObjectURL(url);
    }

    // Clear all data
    clearAllData() {
        if (confirm('Are you sure you want to delete all expenses? This action cannot be undone.')) {
            this.expenses = [];
            this.saveToStorage();
            this.updateSummary();
            this.renderExpenses();
            this.showNotification('All expenses cleared!');
        }
    }
}

// Global functions for button clicks
function startApp() {
    document.getElementById('app').scrollIntoView({ behavior: 'smooth' });
}

function scrollToFeatures() {
    document.getElementById('features').scrollIntoView({ behavior: 'smooth' });
}

// Initialize the app when DOM is loaded
document.addEventListener('DOMContentLoaded', () => {
    window.expenseTracker = new ExpenseTracker();
});

// Add some CSS for animations
const style = document.createElement('style');
style.textContent = `
    .expense-item {
        animation: slideIn 0.3s ease-out;
    }
    
    @keyframes slideIn {
        from {
            opacity: 0;
            transform: translateY(-10px);
        }
        to {
            opacity: 1;
            transform: translateY(0);
        }
    }
    
    .hamburger.active .bar:nth-child(2) {
        opacity: 0;
    }
    
    .hamburger.active .bar:nth-child(1) {
        transform: translateY(8px) rotate(45deg);
    }
    
    .hamburger.active .bar:nth-child(3) {
        transform: translateY(-8px) rotate(-45deg);
    }
`;
document.head.appendChild(style);