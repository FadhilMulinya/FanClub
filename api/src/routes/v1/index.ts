import { Router } from 'express';
import mpesaGroup from './mpesaGroup';

const router: Router = Router();

router.use('/mpesa', mpesaGroup);

export default router;
