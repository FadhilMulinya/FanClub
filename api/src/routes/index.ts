import v1 from './v1';
import { Router } from 'express';

const router: Router = Router();

// Version 1
router.use('/api/v1', v1);

export default router;
