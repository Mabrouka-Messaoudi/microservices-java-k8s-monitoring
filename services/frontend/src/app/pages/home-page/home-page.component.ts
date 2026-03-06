import {Component, inject, OnInit} from '@angular/core';
import {OidcSecurityService} from "angular-auth-oidc-client";
import {Product} from "../../model/product";
import {ProductService} from "../../services/product/product.service";
import {AsyncPipe, JsonPipe} from "@angular/common";
import {Router} from "@angular/router";
import {Order} from "../../model/order";
import {FormsModule} from "@angular/forms";
import {OrderService} from "../../services/order/order.service";
import {filter, switchMap, take} from "rxjs";

@Component({
  selector: 'app-homepage',
  templateUrl: './home-page.component.html',
  standalone: true,
  imports: [AsyncPipe, JsonPipe, FormsModule],
  styleUrl: './home-page.component.css'
})
export class HomePageComponent implements OnInit {
  private readonly oidcSecurityService = inject(OidcSecurityService);
  private readonly productService = inject(ProductService);
  private readonly orderService = inject(OrderService);
  private readonly router = inject(Router);

  isAuthenticated = false;
  products: Array<Product> = [];
  quantityIsNull = false;
  orderSuccess = false;
  orderFailed = false;

  ngOnInit(): void {
    // Track auth state for UI (show/hide buttons etc.)
    this.oidcSecurityService.isAuthenticated$.subscribe(
      ({isAuthenticated}) => {
        this.isAuthenticated = isAuthenticated;
      }
    );

    // Load products only AFTER token is ready — filter(true) + take(1) prevents
    // double-loading and prevents the 401 from firing before auth completes
    this.oidcSecurityService.isAuthenticated$
      .pipe(
        filter(({isAuthenticated}) => isAuthenticated),
        take(1),
        switchMap(() => this.productService.getProducts())
      )
      .subscribe({
        next: (products) => {
          this.products = products;
        },
        error: (err) => {
          console.error('Failed to load products', err);
        }
      });
  }

  goToCreateProductPage() {
    this.router.navigateByUrl('/add-product');
  }
  goToAddInventoryPage(): void {
    this.router.navigate(['/add-inventory']);
  }

  orderProduct(product: Product, quantity: string) {
    if (!quantity) {
      this.orderFailed = true;
      this.orderSuccess = false;
      this.quantityIsNull = true;
      return;
    }

    this.oidcSecurityService.userData$.pipe(take(1)).subscribe(result => {
      const userDetails = {
        email: result.userData.email,
        firstName: result.userData.given_name,
        lastName: result.userData.family_name
      };

      const order: Order = {
        skuCode: product.skuCode,
        price: product.price,
        quantity: Number(quantity),
        userDetails: userDetails
      };

      this.orderService.orderProduct(order).subscribe({
        next: () => {
          this.orderSuccess = true;
          this.orderFailed = false;
          this.quantityIsNull = false;
        },
        error: () => {
          this.orderFailed = true;
          this.orderSuccess = false;
        }
      });
    });
  }
}
