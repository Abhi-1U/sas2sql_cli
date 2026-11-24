data work.order_summary;
  set work.orders;
  keep Order_ID Region Order_Date Shipped_At Cutoff_Time Amount;
run;
