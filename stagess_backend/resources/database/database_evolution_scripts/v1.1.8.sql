/* Initialize the transaction */
START TRANSACTION;

/*********************/
/*** ADMIN SECTION ***/
/*********************/

ALTER TABLE enterprise_jobs
    DROP COLUMN minimum_age;


/* Terminate the transaction */
COMMIT;
